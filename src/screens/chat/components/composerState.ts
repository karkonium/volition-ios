export const messageLimit = 4000;

export function composerState(draft: string, pending: boolean) {
  return {
    canSend: !pending && draft.length <= messageLimit && !!draft.trim(),
    showCount: draft.length >= messageLimit - 200,
  };
}
