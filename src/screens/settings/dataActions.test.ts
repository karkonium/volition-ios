import { configureStore } from "@reduxjs/toolkit";
import chat, { chatActions } from "../../redux/chatSlice";
import activityLog, { activityLogActions } from "../../redux/activityLogSlice";
import grants, { grantsActions } from "../../redux/grantsSlice";

test("clearing chat and activity remain distinct from enforcement history", () => {
  const store = configureStore({ reducer: { chat, activityLog, grants } });
  store.dispatch(chatActions.draftChanged("private draft"));
  store.dispatch(
    activityLogActions.added({
      id: "entry",
      date: "2026-01-01T00:00:00Z",
      message: "request",
      decision: null,
      outcome: "pending",
    }),
  );
  store.dispatch(
    grantsActions.legacyWaitImported({ app: "2026-01-02T00:00:00Z" }),
  );
  store.dispatch(chatActions.cleared());
  store.dispatch(grantsActions.offersCancelled());
  expect(store.getState().chat.draft).toBe("");
  expect(store.getState().activityLog.entries).toHaveLength(1);
  expect(store.getState().grants.hardWaits.app).toBe("2026-01-02T00:00:00Z");
  store.dispatch(chatActions.draftChanged("new draft"));
  store.dispatch(activityLogActions.cleared());
  expect(store.getState().activityLog.entries).toHaveLength(0);
  expect(store.getState().chat.draft).toBe("new draft");
  expect(store.getState().grants.hardWaits.app).toBe("2026-01-02T00:00:00Z");
});
