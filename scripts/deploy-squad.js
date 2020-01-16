// We require the Buidler Runtime Environment explicitly here. This is optional
// when running the script with `buidler run <script>`: you'll find the Buidler
// Runtime Environment's members available as global variable in that case.
const env = require("@nomiclabs/buidler");
const BigNumber = require("bignumber.js");

async function main() {
  // You can run Buidler tasks from a script.
  // For example, we make sure everything is compiled by running "compile"
  await env.run("compile");
  const accounts = await env.web3.eth.getAccounts();

  // Deploy factory
  const Fantastic12Factory = env.artifacts.require("Fantastic12Factory");
  const factory = await Fantastic12Factory.new();
  console.log(`Deployed Fantastic12Factory at address ${factory.address}`);

  // Deploy squad
  const PRECISION = 1e18;
  const withdrawLimit = BigNumber(1000 * PRECISION);
  const consensusThreshold = BigNumber(0.75 * PRECISION);
  const shareTokenName = "Fantastic12 Share Token";
  const shareTokenSymbol = "SHARE";
  const shareTokenDecimals = 18;
  const summonerShareAmount = BigNumber(100 * PRECISION);
  const result = await factory.createSquad(accounts[0], withdrawLimit, consensusThreshold,
    shareTokenName, shareTokenSymbol, shareTokenDecimals, summonerShareAmount);
  const squadAddress = result.logs[0].args.squad;
  console.log(`Deployed Fantastic12 squad at address ${squadAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
