const TaleDaoRoyalty = artifacts.require("TaleDaoRoyalty");

module.exports = function(deployer) {

  deployer.deploy(TaleDaoRoyalty, "v123456Z", ["0x01303af7f6f693af5889444ba7646ef7c4f9fe6d"], [100]);

};

