#!/usr/bin/env node
/**
 * tag-evidence.mjs -- tag every object a pipeline run archived in S3
 * with its artifact class, format, SSDF task, NIST's SP 800-53 mapping
 * for that task (SSDF 1.1 and the 1.2 draft), whose tie between the
 * artifact and the task it is, and its CI/CD atlas page, from
 * evidence-tags.json beside this script; read each object's tags back;
 * and upload tag-manifest.json beside the evidence, one JSON object per
 * line per object, for Athena (clubstraylight.com CSL-0247, CSL-0257).
 *
 * The run is found, not passed: the latest directory under
 * <root>/YYYY/MM/DD/ (today, then yesterday, UTC) whose name ends in the
 * commit's short SHA, the layout attest.mjs and attest.rb write. So no
 * attest script changes; the step runs after the attest step with the
 * same AWS credentials. A file no class matches, or more than one, or
 * tags that read back different, fail the step.
 *
 * Needs, on <bucket>/<root>/*: s3:PutObject, s3:PutObjectTagging,
 * s3:GetObjectTagging; on the bucket: s3:ListBucket for that prefix.
 *
 *   node tag-evidence.mjs [--sha SHA] [--date YYYY/MM/DD] [--dry-run]
 *
 * --dry-run lists and classes the run and writes the manifest locally,
 * tagging and uploading nothing. --sha and --date tag a past run.
 *
 * Environment:
 *   S3_COMPLIANCE_BUCKET  bucket; unset -> nothing to tag, exit 0
 *   AWS_REGION            default us-east-1
 *   EVIDENCE_BUNDLE       prefix root, e.g. "slacronym/ci"; default
 *                         "<repository name>/ci" from GITHUB_REPOSITORY
 *   GITHUB_SHA            the commit, unless --sha
 *   EVIDENCE_DIRS         comma-separated local directories holding the
 *                         archived files, for their digests
 *                         (default "ci-artifacts,ci-output,.")
 *   OUTPUT_DIR            where tag-manifest.json is written (default ".")
 */
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const MANIFEST = "tag-manifest.json";
const argv = process.argv.slice(2);
const option = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};
const dryRun = argv.includes("--dry-run");
const table = JSON.parse(readFileSync(new URL("./evidence-tags.json", import.meta.url), "utf8"));
const bucket = process.env.S3_COMPLIANCE_BUCKET || "";
const region = process.env.AWS_REGION || "us-east-1";
const commit = option("--sha") || process.env.GITHUB_SHA || "";
const sha = commit.slice(0, 7);
const root = (process.env.EVIDENCE_BUNDLE || "").trim().replace(/\/+$/, "") ||
  `${(process.env.GITHUB_REPOSITORY || "repo").split("/").pop()}/ci`;
const dirs = (process.env.EVIDENCE_DIRS || "ci-artifacts,ci-output,.").split(",").map((d) => d.trim());
const outputDir = process.env.OUTPUT_DIR || ".";

if (!bucket) {
  console.log("tag-evidence: S3_COMPLIANCE_BUCKET not set; nothing to tag");
  process.exit(0);
}
if (sha.length < 7) {
  console.error("tag-evidence: no commit SHA (GITHUB_SHA or --sha)");
  process.exit(1);
}

const aws = (args) => execFileSync("aws", [...args, "--region", region], { encoding: "utf8" });

function day(offset) {
  const d = new Date(Date.now() - offset * 86400000);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}/${pad(d.getUTCMonth() + 1)}/${pad(d.getUTCDate())}`;
}

// Every key under <root>/<date>/ for the commit, grouped by run directory.
function runsOn(date) {
  const listed = JSON.parse(aws([
    "s3api", "list-objects-v2", "--bucket", bucket, "--prefix", `${root}/${date}/`,
    "--query", "Contents[].{Key: Key, Size: Size}", "--output", "json",
  ])) || [];
  const runs = {};
  for (const { Key, Size } of listed) {
    const run = Key.split("/").slice(-2)[0];
    if (!run.endsWith(`-${sha}`)) continue;
    (runs[run] ||= []).push({ key: Key, size: Size });
  }
  return runs;
}

const dates = option("--date") ? [option("--date")] : [day(0), day(1)];
let found;
for (const date of dates) {
  const runs = runsOn(date);
  const latest = Object.keys(runs).sort().pop();
  if (latest) {
    found = { date, run: latest, objects: runs[latest] };
    break;
  }
}
if (!found) {
  console.error(`tag-evidence: no run for ${sha} under s3://${bucket}/${root}/ on ${dates.join(" or ")}`);
  process.exit(1);
}

const prefix = `${root}/${found.date}/${found.run}`;
const objects = found.objects.filter(({ key }) => !key.endsWith(`/${MANIFEST}`));

// The local copy of an archived file, for its digest.
function digest(name) {
  const path = dirs.map((dir) => `${dir}/${name}`).find((p) => existsSync(p));
  return path ? createHash("sha256").update(readFileSync(path)).digest("hex") : null;
}

const faults = [];
const lines = [];
for (const { key, size } of objects) {
  const name = key.slice(key.lastIndexOf("/") + 1);
  const rules = table.artifacts.filter((rule) => new RegExp(rule.match).test(name));
  if (rules.length !== 1) {
    faults.push(`${name}: ${rules.length} classes match`);
    continue;
  }
  const rule = rules[0];
  const task = table.tasks[rule["ssdf-task"]];
  const tags = {
    "artifact-class": rule["artifact-class"],
    format: rule.format,
    "ssdf-task": rule["ssdf-task"],
    "sp800-53-ssdf-1.1": task["sp800-53-ssdf-1.1"],
    "sp800-53-ssdf-1.2-draft": task["sp800-53-ssdf-1.2-draft"],
    "mapping-basis": rule["mapping-basis"],
    "atlas-page": rule["atlas-page"],
  };
  let readBack = tags;
  if (!dryRun) {
    const tagging = { TagSet: Object.entries(tags).map(([Key, Value]) => ({ Key, Value })) };
    aws(["s3api", "put-object-tagging", "--bucket", bucket, "--key", key, "--tagging", JSON.stringify(tagging)]);
    const got = JSON.parse(aws(["s3api", "get-object-tagging", "--bucket", bucket, "--key", key]));
    readBack = Object.fromEntries(got.TagSet.map(({ Key, Value }) => [Key, Value]));
  }
  const match = JSON.stringify(Object.entries(readBack).sort()) === JSON.stringify(Object.entries(tags).sort());
  if (!match) faults.push(`${name}: tags read back differ from those written`);
  lines.push({
    schema_version: 1,
    repo: root.split("/")[0],
    run: found.run,
    commit_sha: commit,
    key,
    name,
    size,
    sha256: digest(name),
    artifact_class: rule["artifact-class"],
    format: rule.format,
    ssdf_task: rule["ssdf-task"],
    sp800_53_ssdf_1_1: task["sp800-53-ssdf-1.1"].split(" "),
    sp800_53_ssdf_1_2_draft: task["sp800-53-ssdf-1.2-draft"].split(" "),
    mapping_basis: rule["mapping-basis"],
    atlas_page: rule["atlas-page"],
    tags: readBack,
    tags_match: match,
    tagged_at: new Date().toISOString(),
  });
  console.log(`  ${name}: ${rule["artifact-class"]}, ${rule["ssdf-task"]}${match ? "" : " (MISMATCH)"}`);
}

const manifestPath = `${outputDir}/${MANIFEST}`;
writeFileSync(manifestPath, lines.map((line) => JSON.stringify(line)).join("\n") + "\n");
if (!dryRun) aws(["s3", "cp", manifestPath, `s3://${bucket}/${prefix}/${MANIFEST}`]);

if (faults.length > 0) {
  for (const fault of faults) console.error(`  fault ${fault}`);
  process.exit(1);
}
console.log(dryRun
  ? `${lines.length} objects classed under ${prefix}/; ${manifestPath} written (dry run, nothing sent)`
  : `${lines.length} objects tagged and read back under s3://${bucket}/${prefix}/; ${MANIFEST} uploaded`);
