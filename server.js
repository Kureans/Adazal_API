const express = require('express');
const { Client } = require('pg');
const port = 3000;

const app = express();

app.get('/', (req, res) => {
    res.send("Hello World!");
})
app.listen(port, () => {
    console.log(`Example App Listening on Port ${port}`);
});