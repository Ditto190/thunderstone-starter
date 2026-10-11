const { send } = require("./http");

module.exports = function health(req, res) {
  return send(req, res, "/health");
};
