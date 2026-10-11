const { send } = require("../http");

module.exports = function domain(req, res) {
  return send(req, res, "/v1/domain");
};
