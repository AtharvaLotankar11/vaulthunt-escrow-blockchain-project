"use client";

import { useCallback, useState } from "react";

/** Busy flag and error text for an async button handler. run(fn) never throws. */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const run = useCallback(async (fn) => {
    setBusy(true);
    setError("");
    try {
      return await fn();
    } catch (e) {
      setError(e.message);
      return undefined;
    } finally {
      setBusy(false);
    }
  }, []);
  return { busy, error, run };
}
