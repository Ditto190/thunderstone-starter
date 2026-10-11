export type DomainFinding = {
  kind: string;
  id: string;
  detail: string;
};

export type DomainReport = {
  clan: string;
  stage: string | null;
  reason: string;
  signals: Record<string, boolean>;
  roles: { id: string; name: string; owns: string }[];
  findings: DomainFinding[];
};

export function analyzeWorkspace(
  root: string,
  signalInput?: Record<string, boolean>,
): DomainReport;
