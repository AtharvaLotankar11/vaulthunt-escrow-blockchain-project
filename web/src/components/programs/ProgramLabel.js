"use client";

import { useProfile, useProgram } from "@/lib/hooks";

/** A program's name when it published one, otherwise "Program #n". */
export function ProgramLabel({ programId }) {
  const { data: program } = useProgram(programId);
  const { data: profile } = useProfile(program?.profileURI);
  return <>{profile?.name ?? `Program #${programId}`}</>;
}
