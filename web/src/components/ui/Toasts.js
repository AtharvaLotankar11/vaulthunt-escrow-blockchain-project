"use client";

import { Check, Clock, X } from "lucide-react";
import { createContext, useCallback, useContext, useMemo, useRef, useState } from "react";

const ToastContext = createContext(null);

/** Transaction messages: pending, confirmed, failed (design.md 7.8: slate, magenta bar). */
export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const nextId = useRef(1);

  const remove = useCallback((id) => setToasts((list) => list.filter((t) => t.id !== id)), []);

  const schedule = useCallback(
    (id, tone) => {
      if (tone && tone !== "pending") setTimeout(() => remove(id), tone === "error" ? 9000 : 6000);
    },
    [remove],
  );

  const push = useCallback(
    (toast) => {
      const id = nextId.current++;
      setToasts((list) => [...list.slice(-3), { id, ...toast }]);
      schedule(id, toast.tone);
      return id;
    },
    [schedule],
  );

  const update = useCallback(
    (id, patch) => {
      setToasts((list) => list.map((t) => (t.id === id ? { ...t, ...patch } : t)));
      schedule(id, patch.tone);
    },
    [schedule],
  );

  const api = useMemo(() => ({ push, update, remove }), [push, update, remove]);

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div aria-live="polite" className="pointer-events-none fixed bottom-4 right-4 z-50 flex w-[min(24rem,calc(100vw-2rem))] flex-col gap-2">
        {toasts.map((t) => (
          <div key={t.id} role="status" className="pointer-events-auto flex gap-3 border-l-[6px] border-accent bg-surface p-4">
            <span className="mt-0.5" aria-hidden="true">
              {t.tone === "success" ? <Check size={18} /> : t.tone === "error" ? <X size={18} /> : <Clock size={18} />}
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-sm uppercase">
                {t.tone === "success" ? "Confirmed" : t.tone === "error" ? "Failed" : "Pending"}: {t.title}
              </p>
              {t.text && <p className="mt-1 break-words text-sm text-muted">{t.text}</p>}
            </div>
            <button type="button" aria-label="Dismiss" className="self-start text-muted hover:text-white" onClick={() => remove(t.id)}>
              <X size={16} />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToasts() {
  const value = useContext(ToastContext);
  if (!value) throw new Error("useToasts must be used inside ToastProvider");
  return value;
}
