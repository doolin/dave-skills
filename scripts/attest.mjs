#!/usr/bin/env node

/**
 * CI/CD Attestation Pipeline
 *
 * Zips CI artifacts, computes SHA-256 of the archive, anchors the checksum
 * on Solana via a memo transaction, generates a PDF attestation report,
 * and uploads everything to S3.
 *
 * Environment variables:
 *   GITHUB_SHA            — commit hash (falls back to git rev-parse HEAD)
 *   GITHUB_REPOSITORY     — e.g. owner/repo (set by Actions)
 *   GITHUB_REF_NAME       — branch name (set by Actions)
 *   GITHUB_RUN_ID         — numeric run ID (set by Actions)
 *   GITHUB_SERVER_URL     — e.g. https://github.com (set by Actions)
 *   ARTIFACT_DIR          — directory containing downloaded CI artifacts
 *   OUTPUT_DIR            — directory for output files (zip, pdf)
 *   SOLANA_KEYPAIR_PATH   — path to 64-byte JSON array keypair file
 *   SOLANA_NETWORK        — "devnet" or "mainnet-beta" (default: devnet)
 *   S3_COMPLIANCE_BUCKET  — S3 bucket name (empty = skip S3)
 *   AWS_REGION            — AWS region (default: us-east-1)
 */

import { readFileSync, createWriteStream, existsSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { execSync } from "node:child_process";
import { resolve } from "node:path";

import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  clusterApiUrl,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import archiver from "archiver";
import PDFDocument from "pdfkit";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const MEMO_PROGRAM_ID = new PublicKey("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
const ZIP_FILENAME = "ci-artifacts.zip";
const PDF_FILENAME = "attestation.pdf";

const ARTIFACT_FILES = [
  "lint-results.txt",
];

function getCommitSha() {
  if (process.env.GITHUB_SHA) return process.env.GITHUB_SHA;
  try {
    return execSync("git rev-parse HEAD", { encoding: "utf8" }).trim();
  } catch {
    return "unknown";
  }
}

function buildS3Prefix(commitShort) {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const datePart = `${now.getUTCFullYear()}/${pad(now.getUTCMonth() + 1)}/${pad(now.getUTCDate())}`;
  const timePart = `${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}`;
  const repo = (process.env.GITHUB_REPOSITORY || "repo").split("/").pop();
  return `${repo}/ci/${datePart}/${timePart}-${commitShort}`;
}

// ---------------------------------------------------------------------------
// Step 1: Zip artifacts
// ---------------------------------------------------------------------------

async function zipArtifacts(artifactDir, outputDir) {
  const present = ARTIFACT_FILES.filter((f) => existsSync(`${artifactDir}/${f}`));
  if (present.length === 0) {
    throw new Error(
      `No CI artifact files found in ${artifactDir}. Expected: ${ARTIFACT_FILES.join(", ")}`
    );
  }

  mkdirSync(outputDir, { recursive: true });
  const zipPath = `${outputDir}/${ZIP_FILENAME}`;
  const output = createWriteStream(zipPath);
  const archive = archiver("zip", { zlib: { level: 9 } });

  await new Promise((ok, fail) => {
    output.on("close", ok);
    archive.on("error", fail);
    archive.pipe(output);
    for (const f of present) {
      archive.file(`${artifactDir}/${f}`, { name: f });
    }
    archive.finalize();
  });

  return { zipPath, includedFiles: present };
}

// ---------------------------------------------------------------------------
// Step 2: SHA-256 the zip archive
// ---------------------------------------------------------------------------

function computeChecksum(filePath) {
  const hash = createHash("sha256");
  hash.update(readFileSync(filePath));
  return hash.digest("hex");
}

// ---------------------------------------------------------------------------
// Step 3: Solana memo transaction
// ---------------------------------------------------------------------------

function loadKeypair(keypairPath) {
  const expanded = resolve(
    keypairPath.startsWith("~/") ? keypairPath.replace("~", process.env.HOME) : keypairPath
  );
  const bytes = JSON.parse(readFileSync(expanded, "utf8").trim());
  if (!Array.isArray(bytes) || bytes.length !== 64) {
    throw new Error("Keypair must be a 64-byte JSON array");
  }
  return Keypair.fromSecretKey(Uint8Array.from(bytes));
}

async function submitSolanaMemo(payload, keypairPath, network) {
  const keypair = loadKeypair(keypairPath);
  const connection = new Connection(clusterApiUrl(network), "confirmed");
  const memoData = Buffer.from(JSON.stringify(payload), "utf-8");

  const instruction = new TransactionInstruction({
    programId: MEMO_PROGRAM_ID,
    keys: [{ pubkey: keypair.publicKey, isSigner: true, isWritable: true }],
    data: memoData,
  });

  return sendAndConfirmTransaction(
    connection,
    new Transaction().add(instruction),
    [keypair],
    { commitment: "confirmed" }
  );
}

// ---------------------------------------------------------------------------
// Step 4: PDF attestation report
// ---------------------------------------------------------------------------

async function generatePdf(evidence, outputPath) {
  const doc = new PDFDocument({ size: "LETTER", margin: 50 });
  const stream = createWriteStream(outputPath);

  await new Promise((ok, fail) => {
    stream.on("finish", ok);
    stream.on("error", fail);
    doc.pipe(stream);

    doc.fontSize(20).font("Helvetica-Bold").text("CI/CD Pipeline Attestation");
    doc.moveDown(0.5);
    doc.fontSize(10).font("Helvetica").text(`Generated: ${evidence.completedAt}`);
    doc.moveTo(50, doc.y + 5).lineTo(562, doc.y + 5).stroke();
    doc.moveDown(1);

    doc.fontSize(14).font("Helvetica-Bold").text("Summary");
    doc.moveDown(0.3);
    doc.fontSize(10).font("Helvetica");
    doc.text(`Repository: ${evidence.repository}`);
    doc.text(`Commit: ${evidence.commitSha}`);
    if (evidence.branch) doc.text(`Branch: ${evidence.branch}`);
    if (evidence.ciRunUrl) doc.text(`CI Run: ${evidence.ciRunUrl}`);
    doc.moveDown(0.7);

    doc.fontSize(14).font("Helvetica-Bold").text("Data Integrity");
    doc.moveDown(0.3);
    doc.fontSize(10).font("Helvetica");
    doc.text("Artifact archive SHA-256 (ci-artifacts.zip):");
    doc.fontSize(9).text(`  sha256:${evidence.artifactChecksum}`);
    doc.moveDown(0.2);
    doc.fontSize(10).text("Files in archive:");
    for (const f of evidence.includedFiles) {
      doc.fontSize(9).text(`  - ${f}`);
    }
    doc.moveDown(0.7);

    doc.fontSize(14).font("Helvetica-Bold").text("Blockchain Anchor");
    doc.moveDown(0.3);
    doc.fontSize(10).font("Helvetica");
    if (evidence.solanaTxSignature) {
      const cluster =
        evidence.solanaNetwork === "mainnet-beta" ? "" : `?cluster=${evidence.solanaNetwork}`;
      doc.text(`Network: Solana (${evidence.solanaNetwork})`);
      doc.text("Transaction Signature:");
      doc.fontSize(8).text(`  ${evidence.solanaTxSignature}`);
      doc
        .fontSize(8)
        .text(
          `  Verify: https://explorer.solana.com/tx/${evidence.solanaTxSignature}${cluster}`
        );
    } else {
      doc.text("No blockchain anchor recorded.");
      if (evidence.solanaError) doc.fontSize(9).text(`  Reason: ${evidence.solanaError}`);
    }
    doc.moveDown(0.7);

    doc.fontSize(14).font("Helvetica-Bold").text("Timeline");
    doc.moveDown(0.3);
    doc.fontSize(10).font("Helvetica");
    for (const s of evidence.steps) {
      doc.text(`${s.name}: ${s.result}`);
    }

    doc.end();
  });
}

// ---------------------------------------------------------------------------
// Step 5: Upload to S3
// ---------------------------------------------------------------------------

function uploadToS3(bucket, prefix, files, region) {
  for (const f of files) {
    execSync(
      `aws s3 cp "${f.path}" "s3://${bucket}/${prefix}/${f.name}" --region "${region}"`,
      { stdio: "inherit" }
    );
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const commitSha = getCommitSha();
  const commitShort = commitSha.slice(0, 7);
  const s3Prefix = buildS3Prefix(commitShort);

  const artifactDir = process.env.ARTIFACT_DIR || ".";
  const outputDir = process.env.OUTPUT_DIR || ".";
  const bucket = process.env.S3_COMPLIANCE_BUCKET || "";
  const keypairPath = process.env.SOLANA_KEYPAIR_PATH || "";
  const network = process.env.SOLANA_NETWORK || "devnet";
  const region = process.env.AWS_REGION || "us-east-1";
  const repository = process.env.GITHUB_REPOSITORY || "unknown/repo";
  const branch = process.env.GITHUB_REF_NAME || "";
  const serverUrl = process.env.GITHUB_SERVER_URL || "";
  const runId = process.env.GITHUB_RUN_ID || "";
  const ciRunUrl =
    serverUrl && runId ? `${serverUrl}/${repository}/actions/runs/${runId}` : "";

  const steps = [];
  const step = (name, result) => {
    const ts = new Date().toISOString();
    steps.push({ name, result: `${result} (${ts})` });
    console.log(`  ${name}: ${result}`);
  };

  const s3Key = `${s3Prefix}/${ZIP_FILENAME}`;

  // 1. Zip
  const { zipPath, includedFiles } = await zipArtifacts(artifactDir, outputDir);
  step("Artifacts zipped", `${includedFiles.length} files -> ${ZIP_FILENAME}`);

  // 2. Checksum
  const checksum = computeChecksum(zipPath);
  step("Checksum computed", `sha256:${checksum}`);

  const evidence = {
    commitSha,
    repository: repository.split("/").pop() || repository,
    branch,
    ciRunUrl,
    s3Key,
    artifactChecksum: checksum,
    includedFiles,
    solanaNetwork: network,
    solanaTxSignature: null,
    solanaError: null,
    completedAt: new Date().toISOString(),
    steps,
  };

  // 3. Solana memo (fault-tolerant)
  if (keypairPath) {
    try {
      const sig = await submitSolanaMemo(
        {
          s3_key: s3Key,
          artifact_checksum: `sha256:${checksum}`,
          commit: commitSha,
          timestamp: evidence.completedAt,
        },
        keypairPath,
        network
      );
      evidence.solanaTxSignature = sig;
      step("Solana memo submitted", sig);
    } catch (err) {
      evidence.solanaError = err.message;
      console.warn(`  Solana memo failed (non-fatal): ${err.message}`);
      step("Solana memo", `FAILED - ${err.message}`);
    }
  } else {
    step("Solana memo", "skipped (SOLANA_KEYPAIR_PATH not set)");
  }

  // 4. PDF
  const pdfPath = `${outputDir}/${PDF_FILENAME}`;
  await generatePdf(evidence, pdfPath);
  step("PDF generated", PDF_FILENAME);

  // 5. S3 upload (fault-tolerant)
  if (bucket) {
    try {
      uploadToS3(
        bucket,
        s3Prefix,
        [
          ...includedFiles.map((f) => ({ path: `${artifactDir}/${f}`, name: f })),
          { path: zipPath, name: ZIP_FILENAME },
          { path: pdfPath, name: PDF_FILENAME },
        ],
        region
      );
      step("Uploaded to S3", `s3://${bucket}/${s3Prefix}/`);
    } catch (err) {
      console.warn(`  S3 upload failed (non-fatal): ${err.message}`);
      step("S3 upload", `FAILED - ${err.message}`);
    }
  } else {
    step("S3 upload", "skipped (S3_COMPLIANCE_BUCKET not set)");
  }

  console.log("\nAttestation complete.");
  console.log(JSON.stringify(evidence, null, 2));
}

main().catch((err) => {
  console.error("Attestation failed:", err);
  process.exit(1);
});
