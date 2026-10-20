export const STAGE_ORDER = ["monitor", "triage", "build"];

export const SIGNALS = {
  incident: { stage: "monitor" },
  defaultCiRed: { stage: "monitor" },
  deployFailed: { stage: "monitor" },
  diffCheckFail: { stage: "triage", needsDirty: true },
  secretRisk: { stage: "triage", needsDirty: true },
  knownRed: { stage: "triage", needsDirty: true },
  workflowTouch: { stage: "triage", needsDirty: true },
  checksRed: { stage: "triage" },
  dirty: { stage: "build" },
  docsOnly: { stage: "build", needsDirty: true },
  aheadWithoutPr: { stage: "build" },
  approvedGreen: { stage: "build" },
  cleanDefault: { stage: "build" },
};

export const COMMANDS = {
  bootstrap: "scripts/bootstrap.sh",
  resume: "scripts/resume.sh",
  doctor: "scripts/doctor.sh",
  installDesktop: "scripts/install-desktop.sh",
  exportDrive: "scripts/export-drive.sh",
  checkpoint: "scripts/checkpoint.sh",
  validate: "scripts/validate.sh",
  hygiene: "scripts/check-hygiene.sh",
  runTask: "scripts/run-task.sh",
  envRun: "scripts/env-run.mjs",
};

export const ANALYZERS = [
  {
    id: "comment-sicko",
    owner: "code-analyst",
    kind: "comment",
    rules: [
      {
        id: "escape-hatch",
        severity: "warning",
        check: "line-pattern",
        pattern: "eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck",
        summary: "check disabled inline",
      },
      {
        id: "hack-marker",
        severity: "note",
        check: "line-pattern",
        pattern: "\\b(TODO|FIXME|HACK|XXX)\\b",
        summary: "unfinished marker",
      },
    ],
  },
  {
    id: "docs-command",
    owner: "domain-keeper",
    kind: "docs",
    rules: [
      {
        id: "script-ref",
        severity: "critical",
        check: "script-ref",
        summary: "documented script is outside the command registry or missing on disk",
      },
    ],
  },
];
