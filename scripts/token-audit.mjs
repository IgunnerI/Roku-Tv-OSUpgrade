// Fails if any color literal in shipped code is not one of the design tokens
// (docs/DESIGN.md). All tokens are fully opaque ("FF" alpha) on purpose.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const tokens = {
  "0x080808FF": "background", "0xF2F0EAFF": "primary text", "0x969696FF": "secondary text",
  "0xF2B84BFF": "accent amber", "0x171717FF": "tile background", "0x333333FF": "subtle border",
};
const manifestColors = new Set(["#080808"]);

const root = new URL("..", import.meta.url).pathname;
const files = (dir) => readdirSync(join(root, dir), { withFileTypes: true })
  .flatMap((e) => (e.isDirectory() ? files(join(dir, e.name)) : [join(dir, e.name)]));

const problems = [];
for (const file of files("components")) {
  readFileSync(join(root, file), "utf8").split("\n").forEach((line, i) => {
    for (const [color] of line.matchAll(/0x[0-9A-Fa-f]{8}/g)) {
      if (!tokens[color]) problems.push(`${file}:${i + 1} ${color} is not a design token`);
    }
  });
}
for (const [color] of readFileSync(join(root, "manifest"), "utf8").matchAll(/#[0-9A-Fa-f]{6}/g)) {
  if (!manifestColors.has(color)) problems.push(`manifest ${color} is not the background token`);
}
if (problems.length) {
  console.log(problems.join("\n"));
  process.exit(1);
}
console.log("Design tokens: every color literal is one of the 6 tokens.");
