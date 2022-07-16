require('dotenv').config();
const express = require('express');
const { Client } = require('pg');
const { readFileSync } = require('fs');
const port = 3000;

const app = express();
const initTables = readFileSync("./db/schema.sql").toString();
const populateTestData = readFileSync("./db/test_data.sql").toString();
const initTriggers = readFileSync("./db/triggers.sql").toString();
const initRoutines = readFileSync("./db/routines.sql").toString();
const initSql = initTables.concat(initTriggers, initRoutines);
const client = new Client();

client.connect();

client.query(initSql, (err, res) => {
    console.log(err, res);
    client.end();
})

app.get('/', (req, res) => {
    res.send("Hello World!");
})

app.listen(port, () => {
    console.log(`Example App Listening on Port ${port}`);
})