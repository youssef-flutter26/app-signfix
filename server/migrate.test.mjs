import { describe, expect, it } from "vitest";
import { createRequire } from "node:module";
import fs from "node:fs";
const require = createRequire(import.meta.url);
const { splitStatements } = require("./migrate");

describe("MySQL migration statement splitting", () => {
  it("drops whole-line comments and splits on statement terminators", () => {
    const sql = "-- header; not a statement\nCREATE TABLE a (id INT);\r\nINSERT INTO a VALUES (1),\n(2);\n";
    expect(splitStatements(sql)).toEqual(["CREATE TABLE a (id INT)", "INSERT INTO a VALUES (1),\n(2)"]);
  });

  it("keeps literal $ values such as bcrypt hashes intact", () => {
    const seed = fs.readFileSync(new URL("../database/seed.demo.mysql.sql", import.meta.url), "utf8");
    expect(splitStatements(seed).join("\n")).toContain("$2b$10$N7YMUi7f4qo0wnpExQagQuR7tpjUD3rcOabitmozbImGYkOhlSYW6");
  });
});

describe("MySQL pool adapter", () => {
  const { toMysql } = require("./mysqlPool");

  it("rewrites numbered placeholders, including repeated ones", () => {
    expect(toMysql("SELECT * FROM t WHERE a=$1 OR b=$1 AND c=$2", ["x", 5])).toEqual({ sql: "SELECT * FROM t WHERE a=? OR b=? AND c=?", values: ["x", "x", 5] });
  });

  it("leaves JSON paths alone and serializes object parameters", () => {
    const { sql, values } = toMysql("UPDATE t SET d=JSON_SET(d,'$.note',$1) WHERE id=$2", [{ a: 1 }, 3]);
    expect(sql).toBe("UPDATE t SET d=JSON_SET(d,'$.note',?) WHERE id=?");
    expect(values).toEqual(['{"a":1}', 3]);
  });
});
