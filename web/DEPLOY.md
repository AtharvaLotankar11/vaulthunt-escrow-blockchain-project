# Deploying VaultHunt (website only)

The contracts already live on Sepolia, so only the website needs hosting. Free plans are enough: Vercel (Hobby, personal and non-commercial use) and Pinata (free plan).

## 1. Pinata: storage for reports (about 5 minutes)
1. Sign up at app.pinata.cloud.
2. **API Keys**, then **New Key**. Name it `vaulthunt`, give it **Admin** access, and create it.
3. Copy the **JWT** (a very long text starting with `eyJ`) into a private note. It is shown once. Never put it in git or in chat.
4. Optional: if the **Gateways** page shows your own gateway (like `your-name.mypinata.cloud`), note it as `https://your-name.mypinata.cloud/ipfs`. If not, skip it.

## 2. Vercel: host the website (about 10 minutes)
1. Sign up at vercel.com with your GitHub account (choose the free **Hobby** plan).
2. **Add New**, then **Project**, then import `vaulthunt-escrow-blockchain-project`.
3. **Root Directory**: click Edit and choose **`web`**. Leave the framework as Next.js. The install and build commands come from `web/vercel.json`.
4. Open **Environment Variables** and add:

   | Name | Value |
   |---|---|
   | `NEXT_PUBLIC_DEFAULT_CHAIN` | `sepolia` |
   | `NEXT_PUBLIC_SEPOLIA_RPC` | your Alchemy Sepolia link |
   | `PINATA_JWT` | the JWT from step 1 |
   | `IPFS_GATEWAY` | optional, from step 1.4 |

5. Click **Deploy**. After 2 to 4 minutes you get an address like `https://vaulthunt-xxxx.vercel.app`.
6. Optional: add `NEXT_PUBLIC_SITE_URL` with that address, then **Redeploy**, so the share card shows correctly when the link is pasted into WhatsApp.

Every `git push` to the main branch redeploys the site by itself.

## 3. Test the live site (about 10 minutes)
1. Open the address. You should see the new logo, the tab icon, and under **Live on chain**: Chain 11155111 and Contracts wired.
2. In MetaMask (Sepolia), as the company account, create a program with a small deposit (for example 0.01 ETH).
3. As the hunter account, submit a report. As the company, open **COMPANY**, read the report ("Matches the hash"), and accept.
4. If a step says "Report storage is not set up", `PINATA_JWT` is missing or misspelt. If it says "Pinata refused the upload", the key is wrong or lacks permission; create a new one.

## Notes
- Visitors can browse without a wallet. Creating programs or reports needs MetaMask on Sepolia and free test ETH.
- Demo Mode and the time-jump buttons only work on the local chain.
- Programs and reports created on localhost cannot be read from the live site (the keys live in each browser).
- The Alchemy link is visible inside the website. That is fine for a free test key; replace it after the showcase.
- The Pinata JWT stays on the server and is never sent to the browser.
