import type {
  ScreenTimeBridge,
  ActiveGrant,
} from "../../modules/volition-screen-time";
import type { RootState, AppDispatch } from "../redux/store";
import { chatActions } from "../redux/chatSlice";
import { grantsActions, type Intervention } from "../redux/grantsSlice";
import { activityLogActions } from "../redux/activityLogSlice";
import { resolveAppName } from "./appResolver";
import {
  checkInDue,
  focusProtects,
  recommendedPauseSeconds,
  validateEmotion,
} from "./policy";
import type { CoachDecisionResponse } from "./decision";
import type { DecisionRequest } from "./openaiClient";
import { diagnostic } from "./diagnostics";
export interface CoordinatorDependencies {
  getState: () => RootState;
  dispatch: AppDispatch;
  native: ScreenTimeBridge;
  flush: () => Promise<void>;
  request: (request: DecisionRequest) => Promise<CoachDecisionResponse>;
  foreground: () => boolean;
  now: () => number;
  id: () => string;
  random: () => number;
}
/// Model decisions remain offers until an explicit foreground action passes
/// consent, configuration, Focus, wait and native transaction validation.
export class ConversationCoordinator {
  private pending: AbortController | null = null;
  constructor(private readonly deps: CoordinatorDependencies) {}
  cancel(): void {
    this.pending?.abort();
    this.pending = null;
    this.deps.dispatch(chatActions.requestChanged(null));
  }
  private get state(): RootState {
    return this.deps.getState();
  }
  private date(): string {
    return new Date(this.deps.now()).toISOString();
  }
  private assistant(text: string, appId: string): void {
    this.deps.dispatch(
      chatActions.messageAdded({
        id: this.deps.id(),
        role: "assistant",
        text,
        timestamp: this.date(),
        appId,
      }),
    );
  }
  private assertCurrent(offer: Intervention): void {
    const state = this.state;
    if (
      !this.deps.foreground() ||
      !state.auth.aiConsent ||
      state.auth.authorization !== "approved" ||
      state.auth.consentRevision !== offer.consentRevision ||
      state.apps.nativeFingerprint !== offer.fingerprint ||
      state.grants.offers[offer.appId]?.id !== offer.id ||
      !state.apps.items.some(
        (app) => app.id === offer.appId && app.isEnabled,
      ) ||
      Date.parse(offer.expiresAt) <= this.deps.now()
    )
      throw new Error("This offer has expired. Send a new request.");
    if (
      focusProtects(state.focus, offer.appId, this.deps.now()) ||
      Date.parse(state.grants.hardWaits[offer.appId] ?? "") > this.deps.now()
    )
      throw new Error(
        "This app is still protected. You can continue chatting.",
      );
  }
  async send(explicitAppId?: string): Promise<void> {
    if (this.pending) return;
    const state = this.state,
      rawDraft = state.chat.draft,
      text = rawDraft.trim();
    if (!text) return;
    explicitAppId = explicitAppId ?? state.chat.boundAppId ?? undefined;
    const resolution = resolveAppName(text, state.apps.items);
    if (!explicitAppId && resolution.type === "ambiguous")
      throw new Error("Choose which app you mean. Your draft is saved.");
    const appId =
      explicitAppId ??
      (resolution.type === "selected"
        ? resolution.app.id
        : state.chat.selectedAppId);
    const app = state.apps.items.find(
      (item) => item.id === appId && item.isEnabled,
    );
    if (!app) throw new Error("Choose an app. Your draft is saved.");
    if (!state.auth.aiConsent)
      throw new Error("Enable AI sharing in Privacy & Data to chat.");
    diagnostic("request.started");
    const id = this.deps.id(),
      controller = new AbortController();
    this.pending = controller;
    this.deps.dispatch(chatActions.selected(app.id));
    this.deps.dispatch(chatActions.requestChanged(id));
    const revision = state.auth.consentRevision,
      fingerprint = state.apps.nativeFingerprint;
    this.deps.dispatch(
      chatActions.messageAdded({
        id,
        role: "user",
        text,
        timestamp: this.date(),
        appId: app.id,
      }),
    );
    const due =
      checkInDue(state.grants.lastCheckInAt, this.deps.now()) &&
      this.deps.random() < 0.5;
    const recent = state.grants.accessHistory.filter(
      (item) => Date.parse(item.date) > this.deps.now() - 3600000,
    );
    const deal = state.grants.commitments.find(
      (item) =>
        item.appId === app.id &&
        !item.overriddenAt &&
        Date.parse(item.blockedUntil) > this.deps.now(),
    );
    const logId = this.deps.id();
    this.deps.dispatch(
      activityLogActions.added({
        id: logId,
        appId: app.id,
        appName: app.name,
        date: this.date(),
        message: text,
        decision: null,
        outcome: "pending",
      }),
    );
    try {
      const key = await this.deps.native.getAPIKey();
      if (!key) throw new Error("Add your API key in Coach Settings.");
      const response = await this.deps.request({
        apiKey: key,
        signal: controller.signal,
        consent: () =>
          this.state.auth.aiConsent &&
          this.state.auth.consentRevision === revision,
        context: {
          memory: state.chat.memory,
          appNickname: app.name,
          currentAppID: app.id,
          goals: [app.goal],
          usageProfile: {
            purposes: app.purposes,
            changes: app.changes,
            sessionStyle: app.sessionStyle,
            notes: app.notes,
          },
          currentTime: this.date(),
          timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          tone: state.settings.tone,
          recentMessages: state.chat.messages.slice(-60).concat({
            id,
            role: "user",
            text,
            timestamp: this.date(),
            appId: app.id,
          }),
          accessEvents: state.grants.accessHistory.slice(-100),
          activitySummary: { grantsLastHour: recent.length },
          activeUnlocks: state.grants.activeGrants,
          recommendedIntervention:
            recent.length === 0
              ? "awareness_or_choice"
              : recent.length === 1
                ? "delay"
                : "deal",
          recommendedPauseSeconds: recommendedPauseSeconds(
            state.grants,
            app.id,
            this.deps.now(),
          ),
          preferDeal:
            state.grants.pauseAttempts.filter(
              (item) =>
                item.appId === app.id &&
                Date.parse(item.startedAt) > this.deps.now() - 86400000,
            ).length >= 2,
          emotionCheckInSuggested: due,
          recentReflections: state.grants.reflections
            .filter(
              (item) => Date.parse(item.date) > this.deps.now() - 86400000,
            )
            .slice(-10),
          deal: deal ? { ...deal, canOverride: deal.pushbackCount >= 2 } : null,
          waitUntil: state.grants.hardWaits[app.id] ?? null,
          focusProtected: focusProtects(state.focus, app.id, this.deps.now()),
          recentRemovalAttempts: state.activityLog.removalLedger.slice(-10),
        },
      });
      if (
        controller.signal.aborted ||
        this.state.auth.consentRevision !== revision ||
        this.state.apps.nativeFingerprint !== fingerprint
      )
        throw new Error("Request interrupted. Your draft is saved.");
      diagnostic("request.validated");
      this.deps.dispatch(
        activityLogActions.adviceRecorded({
          id: logId,
          decision: response.decision,
          coachResponse: response.reply,
        }),
      );
      const offer: Intervention = {
        id,
        appId: app.id,
        fingerprint,
        consentRevision: revision,
        decision: response,
        status:
          due && ["pause", "deal", "choice"].includes(response.decision)
            ? "checkIn"
            : "offered",
        createdAt: this.date(),
        expiresAt: new Date(this.deps.now() + 1800000).toISOString(),
        overridingID: deal?.grantId ?? null,
        logId,
      };
      if (["approve", "urgent", "frustration"].includes(response.decision)) {
        this.deps.dispatch(grantsActions.offered(offer));
        await this.activate(app.id, "open");
        this.assistant(response.reply, app.id);
      } else if (
        ["pause", "deal", "choice", "override", "wait"].includes(
          response.decision,
        )
      ) {
        // New wait responses are voluntary offers; legacy hard waits stay separate.
        this.deps.dispatch(grantsActions.offered(offer));
        await this.deps.flush();
        if (offer.status !== "checkIn") {
          this.assistant(response.reply, app.id);
          if (response.decision === "pause" && response.pause_seconds === 10)
            await this.startDelay(app.id);
        }
      } else {
        this.assistant(response.reply, app.id);
        this.deps.dispatch(
          activityLogActions.outcomeRecorded({
            id: logId,
            outcome: response.decision === "deny" ? "denied" : "wait",
          }),
        );
        if (deal) await this.deps.native.recordPushback(app.tokenBase64);
      }
      if (this.state.chat.draft === rawDraft)
        this.deps.dispatch(chatActions.draftChanged(""));
    } catch (error) {
      this.deps.dispatch(
        activityLogActions.outcomeRecorded({
          id: logId,
          outcome: "interrupted",
        }),
      );
      if (!controller.signal.aborted)
        this.deps.dispatch(
          chatActions.failed(
            error instanceof Error
              ? error.message
              : "Request interrupted. Your draft is saved.",
          ),
        );
      diagnostic("request.failed");
    } finally {
      if (this.pending === controller) {
        this.pending = null;
        this.deps.dispatch(chatActions.requestChanged(null));
      }
    }
  }
  async answerCheckIn(appId: string, emotion: string | null): Promise<void> {
    const offer = this.state.grants.offers[appId];
    if (!offer || offer.status !== "checkIn") return;
    this.assertCurrent(offer);
    const answer = emotion === null ? null : validateEmotion(emotion);
    this.deps.dispatch(
      grantsActions.reflected({ appId, date: this.date(), emotion: answer }),
    );
    const revealed = {
      ...offer,
      status: "offered" as const,
      ...(answer ? { emotion: answer } : {}),
    };
    this.deps.dispatch(grantsActions.offerUpdated(revealed));
    this.assistant(offer.decision.reply, appId);
    await this.deps.flush();
    if (
      offer.decision.decision === "pause" &&
      offer.decision.pause_seconds === 10
    )
      await this.startDelay(appId);
  }
  async startDelay(appId: string): Promise<void> {
    const offer = this.state.grants.offers[appId];
    if (!offer || offer.status !== "offered") return;
    this.assertCurrent(offer);
    const seconds =
      offer.decision.pause_seconds ?? (offer.decision.wait_minutes ?? 1) * 60;
    this.deps.dispatch(
      grantsActions.offerUpdated({
        ...offer,
        status: "delaying",
        deadline: new Date(this.deps.now() + seconds * 1000).toISOString(),
        expiresAt: new Date(
          this.deps.now() + (seconds + 1800) * 1000,
        ).toISOString(),
      }),
    );
    this.deps.dispatch(
      grantsActions.pauseStarted({ appId, startedAt: this.date() }),
    );
    await this.deps.flush();
  }
  async endDelay(appId: string): Promise<void> {
    const offer = this.state.grants.offers[appId];
    if (offer?.status === "delaying") {
      this.deps.dispatch(
        grantsActions.offerUpdated({ ...offer, status: "ready" }),
      );
      await this.deps.flush();
    }
  }
  async keepLocked(appId: string): Promise<void> {
    const offer = this.state.grants.offers[appId];
    if (!offer || offer.status === "activating") return;
    this.deps.dispatch(grantsActions.offerRemoved(appId));
    this.deps.dispatch(
      activityLogActions.outcomeRecorded({
        id: offer.logId,
        outcome: "keptLocked",
      }),
    );
    await this.deps.flush();
  }
  async activate(
    appId: string,
    mode: "open" | "deal" | "delay",
  ): Promise<void> {
    const offer = this.state.grants.offers[appId];
    if (
      !offer ||
      ["activating", "interrupted", "checkIn"].includes(offer.status)
    )
      return;
    this.assertCurrent(offer);
    if (
      mode === "delay" &&
      offer.status !== "ready" &&
      !(
        offer.status === "delaying" &&
        Date.parse(offer.deadline ?? "") <= this.deps.now()
      )
    )
      throw new Error("The pause is still running.");
    if (
      mode === "open" &&
      !["approve", "urgent", "frustration", "choice"].includes(
        offer.decision.decision,
      )
    )
      throw new Error("Choose the offered terms.");
    if (
      mode === "deal" &&
      !["deal", "choice", "override"].includes(offer.decision.decision)
    )
      throw new Error("No deal offered.");
    const app = this.state.apps.items.find((item) => item.id === appId);
    if (!app) return;
    const relief = ["urgent", "frustration"].includes(offer.decision.decision);
    this.deps.dispatch(
      grantsActions.offerUpdated({ ...offer, status: "activating" }),
    );
    await this.deps.flush();
    let grant: ActiveGrant | undefined;
    try {
      this.assertCurrent(offer);
      grant = await this.deps.native.createGrant(
        app.tokenBase64,
        offer.decision.unlock_minutes ?? 1,
        offer.fingerprint,
        mode === "deal" ? offer.decision.block_minutes : null,
        (mode === "deal" && offer.decision.decision === "override") || relief
          ? offer.overridingID
          : null,
        relief,
        offer.consentRevision,
      );
      try {
        this.assertCurrent(offer);
      } catch (error) {
        throw error;
      }
      this.deps.dispatch(grantsActions.granted(grant));
      this.deps.dispatch(
        activityLogActions.outcomeRecorded({
          id: offer.logId,
          outcome: "approved",
          grantId: grant.grantId,
        }),
      );
      await this.deps.flush();
      diagnostic("grant.confirmed");
      void this.deps.native
        .syncPresentation()
        .catch(() => diagnostic("presentation.failed"));
    } catch (error) {
      if (grant) {
        await this.deps.native.rollbackGrant(grant.grantId);
        this.deps.dispatch(grantsActions.publicationRolledBack(grant.grantId));
      }
      this.deps.dispatch(grantsActions.offerRemoved(appId));
      this.deps.dispatch(
        activityLogActions.outcomeRecorded({
          id: offer.logId,
          outcome: "interrupted",
        }),
      );
      diagnostic("grant.failed");
      throw error;
    }
  }
}
