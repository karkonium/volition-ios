import type {
  ScreenTimeBridge,
  ActiveGrant,
} from "../../modules/volition-screen-time";
import type { RootState, AppDispatch } from "../redux/store";
import { chatActions } from "../redux/chatSlice";
import { grantsActions, type Intervention } from "../redux/grantsSlice";
import { activityLogActions } from "../redux/activityLogSlice";
import { focusActions } from "../redux/focusSlice";
import {
  focusAccessLimit,
  focusReasons,
  readFocusSnapshot,
} from "./focusStatus";
import { resolveAppName } from "./appResolver";
import { checkInDue, recommendedPauseSeconds, validateEmotion } from "./policy";
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
/// Cancellation invalidates the in-flight offer; late native publication rolls
/// back that grant and late failures cannot replace a newer request's error.
export class ConversationCoordinator {
  private pending: AbortController | null = null;
  private pendingAppId: string | null = null;

  interruptFocusOffers(
    appIds: ReadonlySet<string>,
    cancelPending = false,
  ): void {
    if (cancelPending && this.pendingAppId && appIds.has(this.pendingAppId))
      this.cancel();
    for (const appId of appIds) {
      const offer = this.state.grants.offers[appId];
      if (!offer || offer.status === "activating") continue;
      this.deps.dispatch(grantsActions.offerRemoved(appId));
      this.deps.dispatch(
        activityLogActions.outcomeRecorded({
          id: offer.logId,
          outcome: "interrupted",
        }),
      );
    }
  }

  private async readFocus() {
    const snapshot = readFocusSnapshot(await this.deps.native.getFocus());
    this.deps.dispatch(focusActions.synced(snapshot));
    return this.state.focus;
  }

  private async fitFocus(offer: Intervention): Promise<Intervention | null> {
    const focus = await this.readFocus();
    const limit = focusAccessLimit(focus, offer.appId, this.deps.now());
    if (limit.minutes < 1) return null;
    const requested = offer.decision.unlock_minutes;
    if (requested === null || limit.minutes >= requested) return offer;
    return {
      ...offer,
      focusLimitedUntil: limit.until,
      decision: { ...offer.decision, unlock_minutes: limit.minutes },
    };
  }
  constructor(private readonly deps: CoordinatorDependencies) {}
  cancel(): void {
    const requestId = this.state.chat.pendingRequestId;
    this.pending?.abort();
    if (requestId) {
      for (const offer of Object.values(this.state.grants.offers)) {
        if (offer.id === requestId)
          this.deps.dispatch(grantsActions.offerRemoved(offer.appId));
      }
    }
    this.pending = null;
    this.pendingAppId = null;
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
      focusReasons(state.focus, offer.appId, this.deps.now()).length > 0 ||
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
    if (!explicitAppId && resolution.type === "ambiguous") {
      this.deps.dispatch(chatActions.selectionRequired());
      throw new Error("Choose which app you mean. Your draft is saved.");
    }
    const appId =
      explicitAppId ??
      (resolution.type === "selected"
        ? resolution.app.id
        : state.chat.selectedAppId);
    const app = state.apps.items.find(
      (item) => item.id === appId && item.isEnabled,
    );
    if (!app) {
      this.deps.dispatch(chatActions.selectionRequired());
      throw new Error("Choose an app. Your draft is saved.");
    }
    if (!state.auth.aiConsent)
      throw new Error("Enable AI sharing in Privacy & Data to chat.");
    diagnostic("request.started");
    const id = this.deps.id(),
      controller = new AbortController();
    this.pending = controller;
    this.pendingAppId = app.id;
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
      const [commitments, focus] = await Promise.all([
        this.deps.native.getCommitments(),
        this.readFocus(),
      ]);
      if (
        controller.signal.aborted ||
        this.pending !== controller ||
        !this.state.auth.aiConsent ||
        this.state.auth.consentRevision !== revision
      )
        throw new Error("Request cancelled.");
      this.deps.dispatch(grantsActions.commitmentsSynced(commitments));
      const deal = commitments.find(
        (item) =>
          item.appId === app.id &&
          !item.overriddenAt &&
          Date.parse(item.blockedUntil) > this.deps.now(),
      );
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
            this.state.grants,
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
          focusProtected:
            focusReasons(focus, app.id, this.deps.now()).length > 0,
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
          advice: response,
        }),
      );
      let offer: Intervention = {
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
      const immediate = ["approve", "urgent", "frustration"].includes(
        response.decision,
      );
      const intervention = [
        "pause",
        "deal",
        "choice",
        "override",
        "wait",
      ].includes(response.decision);
      if (immediate || intervention) {
        const fitted = await this.fitFocus(offer);
        if (controller.signal.aborted || this.pending !== controller)
          throw new Error("Request cancelled.");
        if (!fitted) {
          this.deps.dispatch(
            activityLogActions.outcomeRecorded({
              id: logId,
              outcome: "interrupted",
            }),
          );
        } else {
          offer = fitted;
          this.deps.dispatch(grantsActions.offered(offer));
          if (immediate && !offer.focusLimitedUntil) {
            if (await this.activate(app.id, "open"))
              this.assistant(response.reply, app.id);
          } else {
            await this.deps.flush();
            if (offer.status !== "checkIn") {
              // Local copy presents revised terms; model prose may quote the original duration.
              if (!offer.focusLimitedUntil)
                this.assistant(response.reply, app.id);
              if (
                response.decision === "pause" &&
                response.pause_seconds === 10
              )
                await this.startDelay(app.id);
            }
          }
        }
      } else {
        this.assistant(response.reply, app.id);
        this.deps.dispatch(
          activityLogActions.outcomeRecorded({
            id: logId,
            outcome: response.decision === "deny" ? "denied" : "asked",
          }),
        );
        if (
          deal &&
          !focusReasons(this.state.focus, app.id, this.deps.now()).length
        )
          await this.deps.native.recordPushback(app.tokenBase64);
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
      if (!controller.signal.aborted && this.pending === controller)
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
        this.pendingAppId = null;
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
    if (!offer.focusLimitedUntil) this.assistant(offer.decision.reply, appId);
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
  ): Promise<boolean> {
    const offer = this.state.grants.offers[appId];
    if (
      !offer ||
      ["activating", "interrupted", "checkIn"].includes(offer.status)
    )
      return false;
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
    if (!app) return false;
    const relief = ["urgent", "frustration"].includes(offer.decision.decision);
    this.deps.dispatch(
      grantsActions.offerUpdated({ ...offer, status: "activating" }),
    );
    let grant: ActiveGrant | undefined;
    try {
      await this.deps.flush();
      this.assertCurrent(offer);
      const fitted = await this.fitFocus(offer);
      this.assertCurrent(offer);
      if (!fitted) throw new Error("Focus starts before an unlock can fit.");
      if (fitted !== offer) {
        await this.reviseFocusOffer(fitted, mode);
        return false;
      }
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
      return true;
    } catch (error) {
      const code = (error as { code?: string } | null)?.code;
      if (!grant && (code === "FOCUS_BOUNDARY" || code === "FOCUS_ACTIVE")) {
        const fitted = await this.fitFocus(offer).catch(() => null);
        if (
          fitted &&
          fitted !== offer &&
          this.state.grants.offers[appId]?.id === offer.id
        ) {
          await this.reviseFocusOffer(fitted, mode);
          return false;
        }
      }
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

  private async reviseFocusOffer(
    offer: Intervention,
    mode: "open" | "deal" | "delay",
  ) {
    this.deps.dispatch(
      grantsActions.offerUpdated({
        ...offer,
        status: mode === "delay" ? "ready" : "offered",
      }),
    );
    await this.deps.flush();
  }
}
