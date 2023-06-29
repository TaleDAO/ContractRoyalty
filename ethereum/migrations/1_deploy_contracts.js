const SafeMath = artifacts.require("SafeMath");
const TaleDaoRoyalty = artifacts.require("TaleDaoRoyalty");

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.deploy(MultiOwnable);
  deployer.link(SafeMath, TaleDaoRoyalty);
  deployer.link(MultiOwnable, TaleDaoRoyalty);
  deployer.deploy(TaleDaoRoyalty);
};
