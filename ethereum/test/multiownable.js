const MultiOwnable = artifacts.require("MultiOwnable");

contract('MultiOwnable', (accounts) => {

    it('CASE_A_01 quota', async () => {
        const instance = await MultiOwnable.new([accounts[0], accounts[1]], [40, 60], {
            from: accounts[0]
        });

        const quota1 = await instance.getOwnedQuota.call(accounts[0]);
        assert.equal(quota1, 40, "QUOTA_OF_USER_1");

        const quota2 = await instance.getOwnedQuota.call(accounts[1]);
        assert.equal(quota2, 60, "QUOTA_OF_USER_2");

        const quota3 = await instance.getOwnedQuota.call(accounts[2]);
        assert.equal(quota3, 0, "QUOTA_OF_USER_3");

        let raiseError = null;
        try {
            await MultiOwnable.new([accounts[0], accounts[1]], [40, 61], {
                from: accounts[0]
            });
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "SUN_NOT_100_PERCENT");
    });


});

