import { clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/** Join class names; later Tailwind utilities win over earlier ones. */
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}
