#!/usr/bin/env python3
"""Offline fixture checks by default; --live explicitly opts into billed API calls.
Never writes chat, replies, API credentials, or raw provider error bodies to logs.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import sys
import textwrap
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true')
    default_model = re.search(r'static let model = "([^"]+)"', (ROOT / 'OpenAppLock/Services/Conversation/OpenAIConversationClient.swift').read_text()).group(1)
    parser.add_argument('--model', default=default_model)
    args = parser.parse_args()
    cases = json.loads((ROOT / 'Docs/Agents/Evals/coach-cases.json').read_text())
    source = (ROOT / 'OpenAppLock/Services/Conversation/CoachingPolicy.swift').read_text()
    match = re.search(r'static let instructions = """\n(.*?)\n    """', source, re.S)
    if not match:
        sys.exit('Cannot locate the production coaching instructions.')
    instructions = textwrap.dedent(match.group(1))
    ids = [case['id'] for case in cases]
    assert len(ids) == len(set(ids))
    assert all(set(case['allowed']) <= {'ask', 'deny', 'approve', 'wait', 'pause', 'deal', 'override'} for case in cases)
    if not args.live:
        print(f'Validated {len(cases)} evaluation fixtures and the production prompt. No network requests made.')
        return
    key = os.environ.get('OPENAI_API_KEY')
    if not key:
        sys.exit('Set OPENAI_API_KEY in the environment for explicit live evaluation.')
    now = dt.datetime.now(dt.timezone.utc)
    iso = lambda value: value.isoformat().replace('+00:00', 'Z')
    app_id = '11111111-1111-1111-1111-111111111111'
    schema = {'type': 'object', 'additionalProperties': False,
              'required': ['reply', 'decision', 'unlock_minutes', 'wait_minutes', 'pause_seconds', 'block_minutes'],
              'properties': {'reply': {'type': 'string'},
                             'decision': {'type': 'string', 'enum': ['ask', 'deny', 'approve', 'wait', 'pause', 'deal', 'override']},
                             'unlock_minutes': {'type': ['integer', 'null']},
                             'wait_minutes': {'type': ['integer', 'null']},
                             'pause_seconds': {'type': ['integer', 'null']},
                             'block_minutes': {'type': ['integer', 'null']}}}
    failures = 0
    for case in cases:
        count = case.get('recentGrants', 0)
        context = {'goals': ['Use apps intentionally for practical tasks; avoid impulsive repeated scrolling.'],
                   'appNickname': 'Maps', 'currentAppID': app_id, 'memory': case.get('memory', ''), 'timeZone': 'UTC',
                   'currentTime': iso(now), 'tone': 'balanced', 'focusProtected': case.get('focusProtected', False),
                   'recentMessages': [{'id': app_id, 'date': iso(now), 'role': 'user', 'text': case['message']}],
                   'recommendedPauseSeconds': case.get('pauseSeconds', 10),
                   'pauseBeforeDealRequired': not case.get('completedPause', False),
                   'recentReflections': ([{'appID': app_id, 'date': iso(now), 'state': 'completed', 'seconds': 10, 'skipped': False, 'unlockMinutes': 3}] if case.get('completedPause') else []),
                   'recentRemovalAttempts': [], 'accessEvents': [], 'activitySummary': {'grantsLast30Minutes': count, 'grantsLastHour': count,
                       'sameAppGrantsLastHour': count, 'grantedMinutesLastHour': count * 5,
                       'minutesSinceLastGrantEnded': 2 if count else None, 'denialsLastHour': 0},
                   'activeUnlocks': ([{'appID': app_id, 'appName': 'Maps', 'expiresAt': iso(now + dt.timedelta(minutes=3))}]
                                     if case.get('activeGrant') else []),
                   'waitUntil': iso(now + dt.timedelta(minutes=3)) if case.get('activeWait') else None}
        payload = {'model': args.model, 'store': False, 'instructions': instructions,
                   'input': [{'role': 'user', 'content': json.dumps(context)}],
                   'text': {'format': {'type': 'json_schema', 'name': 'access_decision', 'strict': True, 'schema': schema}},
                   'max_output_tokens': 8192}
        if args.model == default_model:
            payload['reasoning'] = {'effort': 'medium'}
        request = urllib.request.Request('https://api.openai.com/v1/responses', data=json.dumps(payload).encode(),
                   headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                envelope = json.load(response)
            assert envelope['status'] == 'completed'
            texts = [part['text'] for item in envelope['output'] if item.get('type') == 'message'
                     for part in item.get('content', []) if part.get('type') == 'output_text']
            assert len(texts) == 1
            decision = json.loads(texts[0])
            unlock, wait = decision.get('unlock_minutes'), decision.get('wait_minutes')
            pause, block = decision.get('pause_seconds'), decision.get('block_minutes')
            valid = decision['decision'] in case['allowed']
            valid &= (type(unlock) is int and 1 <= unlock <= 30 and wait is None) if decision['decision'] in {'approve', 'pause', 'deal', 'override'} else unlock is None
            valid &= (type(wait) is int and 1 <= wait <= 5 and unlock is None) if decision['decision'] == 'wait' else wait is None
            valid &= (type(pause) is int and 10 <= pause <= 1800) if decision['decision'] == 'pause' else pause is None
            valid &= (type(block) is int and 1 <= block <= 1440) if decision['decision'] == 'deal' else block is None
            if decision['decision'] == 'pause' and 'pauseSeconds' in case:
                valid &= pause == case['pauseSeconds']
            failures += not valid
            print(f"{case['id']}: {'PASS' if valid else 'FAIL'} decision={decision['decision']}")
        except urllib.error.HTTPError as error:
            failures += 1
            print(f"{case['id']}: ERROR http_status={error.code}")
        except Exception:
            failures += 1
            print(f"{case['id']}: ERROR invalid_or_unavailable_response")
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
