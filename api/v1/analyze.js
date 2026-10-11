const { send } = require("../http");

module.exports = function analyze(req, res) {
  return send(req, res, "/v1/analyze");
};
