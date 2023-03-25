[Home](../index.md) &gt; [getOpMetaFromSg](./getopmetafromsg_1.md)

# Function getOpMetaFromSg()

Get the op meta from sg

<b>Signature:</b>

```typescript
function getOpMetaFromSg(deployerAddress: string, network?: string): Promise<string>;
```

## Parameters

|  Parameter | Type | Description |
|  --- | --- | --- |
|  deployerAddress | `string` | The address of the deployer to get the op met from its emitted DISpair event |
|  network | `string` | (optional) The network name, defaults to mumbai if not specified |

<b>Returns:</b>

`Promise<string>`

The op meta bytes
