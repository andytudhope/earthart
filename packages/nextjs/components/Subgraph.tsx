import React, { useEffect, useState } from "react";
import { TransactionHash } from "./blockexplorer";
import { Address } from "./scaffold-eth";
import axios from "axios";

interface Collector {
  id: string;
  to: string;
  tokenId: string;
}

const Subgraph: React.FC = () => {
  const [collectors, setCollectors] = useState<Collector[]>([]);

  useEffect(() => {
    const fetchCollectors = async () => {
      try {
        const response = await axios.post(
          "https://api.studio.thegraph.com/query/24825/aether-optimism/version/latest",
          {
            query: `
              query {
                transfers(where: { from: "0x0000000000000000000000000000000000000000" }) {
                  id
                  to
                  tokenId
                }
              }
            `,
          },
        );

        const data = response.data.data;
        const fetchedCollectors: Collector[] = data.transfers;

        setCollectors(fetchedCollectors);
      } catch (error) {
        console.error("Error fetching collectors:", error);
      }
    };

    fetchCollectors();
  }, []);

  return (
    <div>
      <p className="text-4xl bold">NFTs Minted By</p>
      <div className="grid grid-cols-3 gap-4">
        <div className="col-span-1">
          <h3 className="font-bold border-b pb-2">Token ID</h3>
          {collectors.map(collector => (
            <div key={collector.id}>{collector.tokenId}</div>
          ))}
        </div>
        <div className="col-span-1">
          <h3 className="font-bold border-b pb-2">Minter</h3>
          {collectors.map(collector => (
            <div key={collector.id}>
              <Address address={collector.to} />
            </div>
          ))}
        </div>
        <div className="col-span-1 hidden md:block">
          <h3 className="font-bold border-b pb-2">Tx Hash</h3>
          {collectors.map(collector => (
            <div key={collector.id}>
              <TransactionHash hash={collector.id} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Subgraph;
