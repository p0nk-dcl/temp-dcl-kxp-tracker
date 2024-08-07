// #this script handles the ipfs upload 
// + call the script that call the registry smart contract (functions of SC to call: createProfile() + addAttestation('))

import { ethers } from 'ethers';
import { create } from 'ipfs-http-client';

// Replace with your Infura project ID and secret
const projectId = 'YOUR_INFURA_PROJECT_ID';
const projectSecret = 'YOUR_INFURA_PROJECT_SECRET';
const auth = 'Basic ' + Buffer.from(projectId + ':' + projectSecret).toString('base64');

const ipfs = create({
    host: 'ipfs.infura.io',
    port: 5001,
    protocol: 'https',
    headers: {
        authorization: auth,
    },
});

const registryContractAddress = 'YOUR_SMART_CONTRACT_ADDRESS';
const registryContractABI = [
    { 'test': 'test' }
];

interface FormData {
    authorName: string;
    authorWallet: string;
    title: string;
    contributors: string;
    tags: string;
    url: string;
    existingWorkId?: string;
    file?: File;
}

//provider to change !!!
// export const handleSubmit = async (formData: FormData, provider: ethers.providers.Web3Provider) => {
//     let fileCID = '';
//     try {
//         if (formData.file) {
//             const added = await ipfs.add(formData.file);
//             fileCID = added.path;
//         }

//         const metadata = {
//             authorName: formData.authorName,
//             authorWallet: formData.authorWallet,
//             title: formData.title,
//             contributors: formData.contributors,
//             tags: formData.tags,
//             url: formData.url,
//             existingWorkId: formData.existingWorkId,
//             fileCID,
//         };

//         const addedMetadata = await ipfs.add(JSON.stringify(metadata));
//         const metadataCID = addedMetadata.path;

//         const signer = provider.getSigner();
//         const registryContract = new ethers.Contract(registryContractAddress, registryContractABI, signer);
//         const tx = await registryContract.registerResource(metadataCID, formData, await signer.getAddress());
//         await tx.wait();

//         console.log('Resource registered successfully:', tx);
//     } catch (error) {
//         console.error('Error registering resource:', error);
//     }
// };
