# 🌍 Aether, Earth, & Art

## Restoring Dunes with Tunes

We create regenerative art that funds reforestation of exposed sand dunes on Lamu Island, Kenya.

The technical goal of our work here has been to use no-code tools as far as possible, so that we can transfer the basic knowledge and skills required our friends in Kenya. We built the website at [earthart.africa](https://earthart.africa) using [bonfire](https://bonfire.xyz). Bonfire integrates with various no-code NFT tools, and we use [Mintplex](https://mintplex.xyz) to create the NFT contracts we will be using throughout this project.

The most important part of our hack has been ensuring that we set everything up in a way that Collective Sovereignty and Earth Love (the two projects we've partnered with on Lamu) can learn with us and go on to run their own projects in the future. For instance, one of the people involved has written a beautiful meditation on the balance between the Divine Feminine and Masculine and is considering how to use these same tools to create NFTs for that work independently of **Aether, Earth, and Art**.

## Moar Learning

That said, we're not people to only rely on no-code tools. We want to ensure that anyone at any level can use what we have built in their own context.

Therefore, in this repo, you will find a fork of the [Mintplex](https://mintplex.xyz) ERC721A contracts, which have been changed for our particular purpose. 

1. We stripped the "Provider Fee" that Mintplex inserts into all contracts deployed through their platform out. We're not ideologically against people "taxing the congestible" and making money from providing convenience, but we do feel that if people are going to use this repo to learn, then we shouldn't by default expose them to any kind of rent extraction.
2. We split up the single verified contract we got from Etherscan into separate files so that it is easier to reason about.
3. We changed the proxy initialize pattern and moved all that logic into the constructor seeing as we're not using a factory here.
4. We cleaned up the compiler versions across all contracts and made them the same: it is better for learning, though would need to be checked before deploying to prod.
5. We fiddled with the hardhat config file to ensure it does optimization, otherwise the contract is too big to deploy.
6. We changed the deploy script so that the contract and deployed and constructed correctly.

We are deeply indebted to the [🏗 Scaffold-ETH](https://github.com/scaffold-eth/scaffold-eth-2/) for providing such an awesome framework to play with. By following the link above, you can read more about how to use what they have made more extensively. We'll simply include the information necessary to run the code in this repo for brevity.

### Requirements

Before you begin, you need to install the following tools:

- [Node (v18 LTS)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

### Get Started

To get started with Scaffold-ETH 2, follow the steps below:

1. Clone this repo & install dependencies

```
git clone https://github.com/andytudhope/earthart.git
cd earthart
yarn install
```

2. Run a local network in the first terminal:

```
yarn chain
```

This command starts a local Ethereum network using Hardhat. The network runs on your local machine and can be used for testing and development. You can customize the network configuration in `hardhat.config.ts`.

3. On a second terminal, deploy the test contract:

```
yarn deploy
```

This command deploys a test smart contract to the local network. The contract is located in `packages/hardhat/contracts` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `packages/hardhat/deploy` to deploy the contract to the network. You can also customize the deploy script.

4. On a third terminal, start your NextJS app:

```
yarn start
```

Visit your app on: `http://localhost:3000`. We have also included a subgraph in this repo, and implemented an example component to illustrate how to use it to fetch data about which accounts have minted NFTs. All the relevant code is in in `packages/subgraph` and `packages/nextjs/components/Subgraph.tsx`.

### Further Pointers

In order to implement the subgraph, we have pointed SE2 at the Goerli test network. 

We encourage you to tweak the app config in `packages/nextjs/scaffold.config.ts` and set `targetNetwork: chains.hardhat` so you can play with the contract and learn locally. In particular, this will make the Block Explorer tab work again, which is a lot of fun to watch.

We also encourage you to go to the `debug` tab to interact with your contract, see all the functions, and begin to understand how they work. 

You can open minting on your local contract by taking the private key in `packages/hardhat/hardhat.config.ts` at L12, importing it into MetaMask, connecting to that account (rather than a burner wallet) and scrolling down to the `Write` section, where you will find the `openMinting` function. Have fun playing around with everything else you find there.

If you learn from videos better than you do from text, we recommend you sit back, relax, and enjoy [Austin explaining everything here](https://youtu.be/98gMdk5oWmc). Austin will give a great sense of how to begin messing around with this contract and getting it into a state where it has everything you need and nothing you don't.