import { cn } from "@/lib/cn";

export function Card({ plain = false, className, children, ...props }) {
  return (
    <div className={cn("card", plain && "card--plain", className)} {...props}>
      {children}
    </div>
  );
}
