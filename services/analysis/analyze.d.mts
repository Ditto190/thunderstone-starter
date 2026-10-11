export type StageId = "monitor" | "triage" | "build";

export type Finding = {
  analyzer: string;
  rule: string;
  severity: "critical" | "warning" | "note";
  summary: string;
  line?: number;
  path?: string;
};

export type StageAdvice = {
  stage: StageId | null;
  reason: string;
};

export type AnalyzerRule = {
  id: string;
  severity: "critical" | "warning" | "note";
  check: string;
  pattern?: string;
  summary: string;
};

export type Analyzer = {
  id: string;
  owner: string;
  kind: string;
  rules: AnalyzerRule[];
};

export type DomainSnapshot = {
  stages: StageId[];
  signals: Record<string, { stage: StageId; needsDirty?: boolean }>;
  commands: Record<string, string>;
  analyzers: Analyzer[];
};

export function domainSnapshot(): DomainSnapshot;

export function adviseStage(flags: Readonly<Record<string, boolean>>): StageAdvice;

export type AnalysisReport = {
  findings: Finding[];
  stage: StageAdvice | null;
};

export function analyzeText(
  text: string,
  options?: { exists?: (rel: string) => boolean },
): { findings: Finding[] };
