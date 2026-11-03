import { combineReducers, configureStore } from "@reduxjs/toolkit";
import { useDispatch, useSelector } from "react-redux";
import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  persistReducer,
  persistStore,
  FLUSH,
  REHYDRATE,
  PAUSE,
  PERSIST,
  PURGE,
  REGISTER,
} from "redux-persist";
import auth from "./authSlice";
import apps from "./appsSlice";
import chat from "./chatSlice";
import grants from "./grantsSlice";
import focus from "./focusSlice";
import activityLog from "./activityLogSlice";
import settings from "./settingsSlice";
const reducer = combineReducers({
  auth,
  apps,
  chat,
  grants,
  focus,
  activityLog,
  settings,
});
export const store = configureStore({
  reducer: persistReducer<ReturnType<typeof reducer>>(
    { key: "volition-v1", version: 1, storage: AsyncStorage },
    reducer,
  ),
  middleware: (getDefault) =>
    getDefault({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
});
export const persistor = persistStore(store);
export type RootState = ReturnType<typeof reducer>;
export type AppDispatch = typeof store.dispatch;
export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();
