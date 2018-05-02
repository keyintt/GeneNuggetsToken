const GeneNuggetsToken = artifacts.require('./GeneNuggetsToken.sol')

contract('GeneNuggetsToken', function ([owner,CFO,CS,user1,user2]) {
    let contract
    beforeEach('setup contract for each test', async function () {
        contract = await GeneNuggetsToken.new()
    })

    it('creator as owner', async function () {
        assert.equal(await contract.owner(), owner)
    })

    it('name and symbol', async function () {
        assert.equal(await contract.name(), "Gene Nuggets Token")
        assert.equal(await contract.symbol(), "GNUT")
    })

    it('decimals and CAP', async function () {
        assert.equal(await contract.decimals(), 6)
        assert.equal(await contract.CAP(), 30e8 * (10 **6))
    })

    it('revert eth transfer', async function () {
        const contractAddress = await contract.address
        console.log(contractAddress)
        try {
            await web3.eth.sendTransaction({from:user1,to:contractAddress, value:web3.toWei(0.05, "ether")})
            assert.fail()
        } catch (error) {
            console.log(error)
            assert(error.toString().includes('invalid opcode'), error.toString())
        }
    })

    
})