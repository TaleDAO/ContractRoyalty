const Tradeable = artifacts.require("Tradeable");

contract('Tradeable', (accounts) => {

    it('CASE_C_01 allow quota', async () => {

        const instance = await Tradeable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        let sum = await instance.sumAllowedQuota.call();
        assert.equal(sum, 0);

        // set allowed quota
        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.setAllowedQuota(30, {from: accounts[9]});
        sum = (await instance.sumAllowedQuota.call()).toNumber();
        assert.equal(sum, 50);

        // non-owner setting should raise error
        try {
            await instance.setAllowedQuota(50, {from: accounts[7]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOT_ENOUGH");

        // setting too big
        try {
            await instance.setAllowedQuota(50, {from: accounts[8]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOT_ENOUGH");

        // ensure cannot be called externally
        try {
            await instance.allocateQuota(accounts[8], accounts[9], 50);
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.toString(), "TypeError: instance.allocateQuota is not a function");

    });

});

