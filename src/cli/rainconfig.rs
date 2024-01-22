use serde_bytes::ByteBuf;
use serde::{Serialize, Deserialize};
use alloy_primitives::{keccak256, hex};
use rain_meta::{Store, DeployerResponse, RainMetaDocumentV1Item};
use std::{
    path::PathBuf,
    sync::{Arc, RwLock},
    fs::{read, read_to_string, read_dir},
    collections::HashMap,
};

pub(crate) const RAINCONFIG_DESCRIPTION: &str = r"
Description:
rainconfig.json provides configuration details and information required for .rain compiler.

usually it should be placed at the root directory of the working workspace and named as 
'rainconfig.json', however if this is not desired at times, it is possible to pass any path for 
rainconfig when using the dotrain command using --config option.

all fields in the rainconfig are optional and are as follows:

  - include: Specifies a list of directories (files/folders) to be included and watched. 
  'src' files are included by default and folders will be watched recursively for .rain files. 
  These files will be available as dotrain meta in the cas so if their hash is specified in a
  compilation target they will get resolved.

  - subgraphs: Additional subgraph endpoint URLs to include when searching for metas of 
  specified meta hashes in a rainlang document.

  - meta: List of paths of local meta files as binary or utf8 encoded text file containing hex 
  string starting with 0x.

  - deployers: List of ExpressionDeployers data sets which represents all the data required for 
  reproducing it on a local evm, paired with their corresponding hash as a key/value pair, each 
  pair has the fields that hold a path to disk location to read data from, 'expressionDeployer', 
  'parser', 'store', 'interpreter' fields should point to contract json artifact where their 
  bytecode and deployed bytecode can be read from and 'constructionMeta' is specified the same 
  as any other meta.
";
pub(crate) const RAINCONFIG_INCLUDE_DESCRIPTION: &str = r"Specifies a list of directories (files/folders) to be included and watched. 'src' files are included by default and folders will be watched recursively for .rain files. These files will be available as dotrain meta in the cas so if their hash is specified in a compilation target they will get resolved.";
pub(crate) const RAINCONFIG_SUBGRAPHS_DESCRIPTION: &str = r"Additional subgraph endpoint URLs to include when searching for metas of specified meta hashes in a rainlang document.";
pub(crate) const RAINCONFIG_META_DESCRIPTION: &str = r"List of paths (or object of path and hash) of local meta files as binary or utf8 encoded text file containing hex string starting with 0x.";
pub(crate) const RAINCONFIG_DEPLOYERS_DESCRIPTION: &str = r"List of ExpressionDeployers data sets which represents all the data required for reproducing it on a local evm, paired with their corresponding hash as a key/value pair, each pair has the fields that hold a path to disk location to read data from, 'expressionDeployer', 'parser', 'store', 'interpreter' fields should point to contract json artifact where their bytecode and deployed bytecode can be read from and 'constructionMeta' is specified the same as any other meta.";

/// Type of a meta data type
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum RainConfigMetaType {
    /// Indicates a binary data
    Binary(PathBuf),
    /// Indicates a utf8 encoded hex string data
    Hex(PathBuf),
}

/// Data structure of deserialized deployer item from rainconfig.json
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RainConfigDeployer {
    pub construction_meta: RainConfigMetaType,
    pub expression_deployer: PathBuf,
    pub parser: PathBuf,
    pub store: PathBuf,
    pub interpreter: PathBuf,
}

/// Data structure of deserialized rainconfig.json
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub struct RainConfigStruct {
    pub include: Option<Vec<PathBuf>>,
    pub subgraphs: Option<Vec<String>>,
    pub meta: Option<Vec<RainConfigMetaType>>,
    pub deployers: Option<HashMap<String, RainConfigDeployer>>,
}

struct ProcessType(
    Vec<(PathBuf, String)>,
    Vec<(Vec<u8>, Vec<u8>)>,
    Vec<DeployerResponse>,
);

struct ArtifactBytecode(Option<Vec<u8>>, Option<Vec<u8>>);

impl RainConfigStruct {
    /// reads rainconfig from the given path
    pub fn read(path: &PathBuf) -> anyhow::Result<RainConfigStruct> {
        let content = read(path)?;
        let rainconfig: RainConfigStruct = serde_json::from_slice(&content)?;
        Ok(rainconfig)
    }

    pub fn read_included_files(&self, force: bool) -> anyhow::Result<Vec<(PathBuf, String)>> {
        let mut files_contents = vec![];
        if let Some(included_dirs) = &self.include {
            for included_dir in included_dirs {
                match read_dotrain_files(included_dir, force) {
                    Ok(v) => files_contents.extend(v),
                    Err(e) => {
                        if !force {
                            Err(e)?
                        }
                    }
                }
            }
        }
        Ok(files_contents)
    }

    fn process(&self, force: bool) -> anyhow::Result<ProcessType> {
        let mut dotrains = vec![];
        let mut metas = vec![];
        let mut npe2_deployers = vec![];
        match self.read_included_files(force) {
            Ok(v) => dotrains.extend(v),
            Err(e) => {
                if !force {
                    Err(e)?
                }
            }
        }
        if let Some(all_metas) = &self.meta {
            for m in all_metas {
                read_meta(m, &mut metas, force)?;
            }
        }
        if let Some(deployers) = &self.deployers {
            for (hash, deployer) in deployers {
                match read_deployer(hash, deployer) {
                    Ok(v) => {
                        npe2_deployers.push(v);
                    }
                    Err(e) => {
                        if !force {
                            Err(e)?
                        }
                    }
                }
            }
        }
        Ok(ProcessType(dotrains, metas, npe2_deployers))
    }

    /// Build a Store instance from all specified configuraion in rainconfig
    pub fn build_store(&self) -> anyhow::Result<Arc<RwLock<Store>>> {
        let temp: Vec<String> = vec![];
        let subgraphs = if let Some(sgs) = &self.subgraphs {
            sgs
        } else {
            &temp
        };
        let ProcessType(dotrains, metas, mut deployers) = self.process(true)?;
        let mut store = Store::default();
        store.add_subgraphs(subgraphs);
        for (hash, bytes) in metas {
            store.update_with(&hex::decode(&hash)?, &bytes);
        }
        for (path, text) in dotrains {
            if let Some(uri) = path.to_str() {
                let uri = uri.to_string();
                store.set_dotrain(&text, &uri, true)?;
            } else {
                return Err(anyhow::anyhow!(format!(
                    "could not derive a valid utf-8 encoded URI from path: {:?}",
                    path
                )));
            }
        }
        while let Some(deployer) = deployers.pop() {
            store.set_deployer_from_query_response(deployer);
        }
        Ok(Arc::new(RwLock::new(store)))
    }

    /// Builds a Store instance from all specified configuraion in rainconfig by ignoring all erroneous path/items
    pub fn force_build_store(&self) -> anyhow::Result<Arc<RwLock<Store>>> {
        let temp: Vec<String> = vec![];
        let subgraphs = if let Some(sgs) = &self.subgraphs {
            sgs
        } else {
            &temp
        };
        let ProcessType(dotrains, metas, mut deployers) = self.process(false)?;
        let mut store = Store::default();
        store.add_subgraphs(subgraphs);
        for (hash, bytes) in metas {
            store.update_with(&hex::decode(&hash)?, &bytes);
        }
        for (path, text) in dotrains {
            if let Some(uri) = path.to_str() {
                let uri = uri.to_string();
                store.set_dotrain(&text, &uri, true)?;
            }
        }
        while let Some(deployer) = deployers.pop() {
            store.set_deployer_from_query_response(deployer);
        }
        Ok(Arc::new(RwLock::new(store)))
    }
}

/// reads rain files recursively from the provided path
fn read_dotrain_files(path: &PathBuf, force: bool) -> anyhow::Result<Vec<(PathBuf, String)>> {
    let mut files_contents = vec![];
    for read_dir_result in read_dir(path)? {
        let dir = read_dir_result?.path();
        if dir.is_dir() {
            match read_dotrain_files(&dir, force) {
                Ok(v) => files_contents.extend(v),
                Err(e) => {
                    if !force {
                        Err(e)?
                    }
                }
            }
        } else if dir.is_file() {
            if let Some(ext) = dir.extension() {
                if ext == "rain" {
                    match read_to_string(&dir) {
                        Ok(v) => files_contents.push((dir.clone(), v)),
                        Err(e) => {
                            if !force {
                                Err(e)?
                            }
                        }
                    }
                }
            }
        }
    }
    Ok(files_contents)
}

fn read_meta(
    meta: &RainConfigMetaType,
    metas: &mut Vec<(Vec<u8>, Vec<u8>)>,
    force: bool,
) -> anyhow::Result<()> {
    match meta {
        RainConfigMetaType::Binary(binary_meta_path) => match read(binary_meta_path) {
            Ok(data) => {
                metas.push((keccak256(&data).0.to_vec(), data));
            }
            Err(e) => {
                if !force {
                    Err(e)?
                }
            }
        },
        RainConfigMetaType::Hex(hex_meta_path) => match read_to_string(hex_meta_path) {
            Ok(hex_string) => match hex::decode(hex_string) {
                Ok(data) => {
                    metas.push((keccak256(&data).0.to_vec(), data));
                }
                Err(e) => {
                    if !force {
                        return Err(anyhow::anyhow!(format!("{:?} at {:?}", e, hex_meta_path)));
                    }
                }
            },
            Err(e) => {
                if !force {
                    Err(e)?
                }
            }
        },
    }
    Ok(())
}

fn read_deployer(hash: &str, deployer: &RainConfigDeployer) -> anyhow::Result<DeployerResponse> {
    let mut metas = vec![];
    read_meta(&deployer.construction_meta, &mut metas, false)?;
    let (meta_hash, meta_bytes) = if metas.len() == 1 {
        metas.pop().unwrap()
    } else {
        return Err(anyhow::anyhow!("could not reaed construction meta!"));
    };
    let exp_deployer = read_bytecode(&deployer.expression_deployer)?;
    let bytecode = if let Some(v) = exp_deployer.0 {
        v
    } else {
        return Err(anyhow::anyhow!(
            "could not find ExpressionDeployer bytecode!"
        ));
    };
    let bytecode_meta_hash = if let Some(v) = exp_deployer.1 {
        RainMetaDocumentV1Item {
            payload: ByteBuf::from(v),
            magic: rain_meta::KnownMagic::ExpressionDeployerV2BytecodeV1,
            content_type: rain_meta::ContentType::OctetStream,
            content_encoding: rain_meta::ContentEncoding::None,
            content_language: rain_meta::ContentLanguage::None,
        }
        .hash(false)?
        .to_vec()
    } else {
        return Err(anyhow::anyhow!(
            "could not find ExpressionDeployer deployed bytecode!"
        ));
    };
    Ok(DeployerResponse {
        meta_hash,
        meta_bytes,
        bytecode,
        parser: read_bytecode(&deployer.parser)?
            .0
            .ok_or(anyhow::anyhow!(format!(
                "could not read parser deployed bytecode at {:?}",
                deployer.parser
            )))?,
        store: read_bytecode(&deployer.store)?
            .0
            .ok_or(anyhow::anyhow!(format!(
                "could not read store deployed bytecode at {:?}",
                deployer.store
            )))?,
        interpreter: read_bytecode(&deployer.interpreter)?
            .0
            .ok_or(anyhow::anyhow!(format!(
                "could not read interpreter deployed bytecode at {:?}",
                deployer.interpreter
            )))?,
        bytecode_meta_hash,
        tx_hash: hex::decode(hash)?.to_vec(),
    })
}

fn read_bytecode(path: &PathBuf) -> anyhow::Result<ArtifactBytecode> {
    let content = read(path)?;
    let json = serde_json::from_slice::<serde_json::Value>(&content)?;
    let deployed_bytecode = &json["deployedBytecode"]["object"];
    let bytecode = &json["bytecode"]["object"];
    if bytecode.is_string() && deployed_bytecode.is_string() {
        let mut err = Err(anyhow::anyhow!(""));
        let b = match hex::decode(bytecode.as_str().unwrap()) {
            Ok(data) => Some(data),
            Err(e) => {
                err = Err(anyhow::anyhow!(format!("{:?} at {:?}", e, path)));
                None
            }
        };
        let deployed_bytecode_data = match hex::decode(deployed_bytecode.as_str().unwrap()) {
            Ok(data) => Some(data),
            Err(e) => {
                err = Err(anyhow::anyhow!(format!("{:?} at {:?}", e, path)));
                None
            }
        };
        if b.is_none() || deployed_bytecode_data.is_none() {
            err
        } else {
            Ok(ArtifactBytecode(b, deployed_bytecode_data))
        }
    } else if !bytecode.is_string() && deployed_bytecode.is_string() {
        match hex::decode(deployed_bytecode.as_str().unwrap()) {
            Ok(data) => Ok(ArtifactBytecode(None, Some(data))),
            Err(e) => Err(anyhow::anyhow!(format!("{:?} at {:?}", e, path))),
        }
    } else if bytecode.is_string() && !deployed_bytecode.is_string() {
        match hex::decode(bytecode.as_str().unwrap()) {
            Ok(data) => Ok(ArtifactBytecode(Some(data), None)),
            Err(e) => Err(anyhow::anyhow!(format!("{:?} at {:?}", e, path))),
        }
    } else {
        Err(anyhow::anyhow!(format!(
            "artifact at {:?} doesn't contain bytecode/deployed bytecode",
            path
        )))
    }
}
