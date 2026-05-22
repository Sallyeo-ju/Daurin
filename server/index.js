const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.send({ message: "Halo, backend Express sudah jalan!" });
});

app.listen(port, () => {
  console.log(`Server nyala di http://localhost:${port}`);
});