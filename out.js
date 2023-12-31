import PG from "pg";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
function login_nossl_nopassword() {
  return new PG.Client({
    host: "localhost",
    port: 5432,
    database: "auth_db",
    user: "role_ssl_passwd",
    password: "role_ssl_passwd",
    ssl: {
      ca: readFileSync(resolve("./certs/ca.crt"), "utf8"),
    },
    // will crash backend for some reason binary: true,
  });
}
/*
const query1 = {
  text: "PREPARE fooplanx (varchar) AS select oid, typname from pg_type where typname = $1"
};

const query2 = {
  text: "select * from pg_prepared_statements"
};
*/
function delay(ts_in_sec) {
  const ts_in_ms = Math.trunc(ts_in_sec * 1e3);
  return new Promise((resolve) => setTimeout(resolve, ts_in_ms));
}
async function testConnection(connection) {
  const cl = connection();
  await cl.connect();
  {
    const rows = await cl.query({
      name: "foobar",
      //portal: "foobar",
      text: "select oid, typname from pg_type where typname = $1",
      values: ["bool"],
    });
    console.log("prepare plan rows: [%o]", rows);
  }
  await delay(3);
  {
    const rows = await cl.query({
      text: "select * from pg_prepared_statements",
    });
    console.log("query pg_prepared_statements: [%o]", rows);
  }
}
testConnection(login_nossl_nopassword);
//# sourceMappingURL=out.js.map
