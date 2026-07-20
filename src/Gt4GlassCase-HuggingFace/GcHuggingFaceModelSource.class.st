"
ADAPTER: implements the GcModelSource port using a Gt4HuggingFaceClient. The only class that references both the HuggingFace client and Gc domain objects -- it translates generic Hub results (config Dictionary, safetensors header) into GcModelConfig / GcSafetensorsFile / GcRepoManifest. Reads the optional token from ~/.secrets/huggingface-token.txt inside the image and injects it into the client.
"
Class {
	#name : 'GcHuggingFaceModelSource',
	#superclass : 'GcModelSource',
	#instVars : [
		'client',
		'repositoryId',
		'cachedConfig',
		'cachedFile',
		'cachedUndertrainedScan',
		'cachedMergeList'
	],
	#category : 'Gt4GlassCase-HuggingFace',
	#package : 'Gt4GlassCase-HuggingFace'
}

{ #category : 'instance creation' }
GcHuggingFaceModelSource class >> forRepository: aRepoId [
	^ self new
		repositoryId: aRepoId;
		yourself
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> architecture [
	^ self config architecture
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> architectureFor: aRepoId [
	^ (self configFor: aRepoId) architecture
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> buildSafetensorsFileFor: aRepoId file: aFileName header: aHeader [
	"Translate a generic safetensors header into a GcSafetensorsFile of GcTensorRefs, and wire a bytes provider so numeric views can sample tensor values on demand (I5: ranged reads only). The core class parses a plain Dictionary, so it stays decoupled from the HF client."
	| file |
	file := GcSafetensorsFile new.
	file path: aRepoId , '/' , aFileName.
	file parseHeaderDictionary: aHeader rawDictionary.
	file bytesProvider: (GcHuggingFaceBytesProvider client: client repositoryId: aRepoId file: aFileName).
	^ file
]

{ #category : 'initialization' }
GcHuggingFaceModelSource >> clearCache [
	"Drop cached config/file/merge list so the next access re-fetches."
	cachedConfig := nil.
	cachedFile := nil.
	cachedMergeList := nil
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client [
	^ client
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> client: aClient [
	client := aClient
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> config [
	"Cached: fetched once per source."
	^ cachedConfig ifNil: [ cachedConfig := self configFor: repositoryId ]
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> configFor: aRepoId [
	^ GcModelConfig fromDictionary: (client config: aRepoId)
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> embeddingTensorIn: aFile [
	"The 2-D token-embedding tensor (vocab x hidden) of this model's safetensors file."
	^ aFile tensors
		detect: [ :t | self isEmbeddingTensorName: t name ]
		ifNone: [ self error: 'No token-embedding tensor found in ', aFile path ]
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> fileInfo [
	^ self fileInfo: 'model.safetensors'
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> fileInfo: aFileName [
	"The safetensors file with its full tensor tree (like HuggingFace's file-info panel). Open the result's Tree view."
	^ self safetensorsFile: aFileName
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtAnomalousTokensFor: aView [
	<gtView>
	"Which of this model's tokens look like trigger candidates?"
	^ aView forward
		title: 'Odd tokens';
		priority: 8;
		object: [ self tokenGroup ];
		view: #gtAnomalousFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtArchitectureFor: aView [
	"The model architecture. Fetches config.json the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Architecture';
		priority: 3;
		object: [ self architecture ];
		view: #gtOverviewFor:
]

{ #category : 'gt views' }
GcHuggingFaceModelSource >> gtCorpusFingerprintFor: aView [
	<gtView>
	"Corpus fingerprint of the tokenizer's BPE merges. Reads the cached merge list only; run the 'Fetch merge list' action (or an example) to populate it."
	cachedMergeList ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Corpus fingerprint';
		priority: 10;
		object: [ cachedMergeList ];
		view: #gtCorpusFingerprintFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtDeadWeightsFor: aView [
	<gtView>
	"Are there tensors in the file that the architecture never references - and are any expected tensors missing?"
	^ aView columnedList
		title: 'Dead weights';
		priority: 7;
		items: [
			| analysis unreferenced missing matchedCount rows |
			analysis := self architecture deadWeightAnalysisOn: self tensorGroup.
			unreferenced := analysis at: #unreferenced.
			missing := analysis at: #missing.
			matchedCount := analysis at: #matchedCount.
			rows := OrderedCollection new.
			(unreferenced isEmpty and: [ missing isEmpty ])
				ifTrue: [
					rows add: {'all accounted for'.
						'all ' , matchedCount printString , ' tensors matched the architecture template'.
						self} ]
				ifFalse: [
					unreferenced do: [ :ref |
						rows add: {'unreferenced in file'. ref name. ref} ].
					missing do: [ :eachName |
						rows add: {'missing from file'. eachName. eachName} ] ].
			rows ];
		column: 'Status' text: [ :row | row at: 1 ];
		column: 'Tensor' text: [ :row | row at: 2 ];
		send: [ :row | row at: 3 ]
]

{ #category : 'gt actions' }
GcHuggingFaceModelSource >> gtMergeListActionFor: anAction [
	<gtAction>
	^ anAction button
		tooltip: 'Fetch the BPE merge list (tokenizer.json / merges.txt) over HTTP, then open it';
		priority: 26;
		icon: BrGlamorousVectorIcons inspect;
		action: [ :aButton |
			[ | ml |
			ml := self mergeList.
			aButton enqueueTask: (BlTaskAction new action: [
				aButton phlow spawnObject: ml ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'gt actions' }
GcHuggingFaceModelSource >> gtOddTokensActionFor: anAction [
	<gtAction>
	^ anAction button
		tooltip: 'Fetch tokenizer.json over HTTP, then open the anomalous-token group';
		priority: 25;
		icon: BrGlamorousVectorIcons inspect;
		action: [ :aButton |
			[ | group |
			group := self tokenGroup.
			aButton enqueueTask: (BlTaskAction new action: [
				aButton phlow spawnObject: group ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'gt actions' }
GcHuggingFaceModelSource >> gtScanUndertrainedActionFor: anAction [
	<gtAction>
	^ anAction button
		tooltip: 'Fetch vocab + a control band + the anomalous tokens'' embedding rows over bounded HTTP, then scan for undertrained tokens';
		priority: 26;
		icon: BrGlamorousVectorIcons inspect;
		action: [ :aButton |
			[ | scan |
			scan := self scanUndertrainedTokens.
			aButton enqueueTask: (BlTaskAction new action: [
				aButton phlow spawnObject: scan ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'gt views' }
GcHuggingFaceModelSource >> gtShardsFor: aView [
	"The physical shard breakdown. Fetches model.safetensors (or the shard index + shard headers) the first time this tab is opened, then cached. Single-file models show one shard."
	<gtView>
	^ aView forward
		title: 'Shards';
		priority: 6;
		object: [ self safetensorsFile ];
		view: #gtShardsFor:
]

{ #category : 'gt views' }
GcHuggingFaceModelSource >> gtSignalFlowFor: aView [
	"The model's signal-flow / block diagram. Fetches config.json + the safetensors header the first time this tab is opened (then cached), then derives the block wiring from the tensor names."
	<gtView>
	^ aView forward
		title: 'Signal flow';
		priority: 2;
		object: [ GcSignalFlow fromTensorGroup: self tensorGroup architecture: self architecture ];
		view: #gtSignalFlowFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtSkylineFor: aView [
	"The model skyline. Fetches the safetensors header the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Skyline';
		priority: 5;
		object: [ self tensorGroup ];
		view: #gtSkylineFor:
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtSourceFor: aView [
	"What model does this source point at? No network -- this is the safe default view."
	<gtView>
	^ aView columnedList
		title: 'Source';
		priority: 1;
		items: [ self sourceFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcHuggingFaceModelSource >> gtTreeFor: aView [
	"The tensor tree (HuggingFace-style file info). Fetches the safetensors header the first time this tab is opened (then cached)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 4;
		object: [ self tensorTree ];
		view: #gtTreeFor:
]

{ #category : 'gt views' }
GcHuggingFaceModelSource >> gtUndertrainedTokensFor: aView [
	<gtView>
	"Undertrained? -- the embedding-weight refinement of the Odd-tokens lens. Reads the cached scan only; run the 'Scan undertrained tokens' action (or an example) to populate it."
	cachedUndertrainedScan ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Undertrained?';
		priority: 9;
		object: [ cachedUndertrainedScan ];
		view: #gtRankedCandidatesFor:
]

{ #category : 'initialization' }
GcHuggingFaceModelSource >> initialize [
	super initialize.
	client := Gt4HuggingFaceClient new.
	self injectTokenIfPresent
]

{ #category : 'initialization' }
GcHuggingFaceModelSource >> injectTokenIfPresent [
	"Read the optional HF token from a local secrets file inside the image and inject it into the client. The token value is never printed or returned."
	| ref |
	ref := FileLocator home / '.secrets' / 'huggingface-token.txt'.
	ref exists ifTrue: [ client token: ref contents trimmed ]
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> isEmbeddingTensorName: aName [
	"Common token-embedding tensor names across architectures (gpt2 wte, llama/qwen embed_tokens, gpt-neox word_embeddings, ...)."
	^ aName = 'wte.weight'
		or: [ (aName endsWith: 'embed_tokens.weight')
		or: [ (aName endsWith: 'word_embeddings.weight')
		or: [ aName endsWith: 'tok_embeddings.weight' ] ] ]
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> label [
	^ repositoryId
]

{ #category : 'merge list' }
GcHuggingFaceModelSource >> loadMergeList [
	"Fetch the tokenizer's ordered BPE merge list over bounded HTTP: prefer tokenizer.json (single source: model.merges when model.type = 'BPE'); else fall back to the legacy gpt2-style merges.txt. Returns a GcMergeList (~1.4MB for gpt2's tokenizer.json). NOT called from any render block."
	| dict model type merges |
	dict := [ client getJson: (client resolveUrlFor: repositoryId file: 'tokenizer.json') ]
		on: Error do: [ :e | nil ].
	dict ifNotNil: [
		model := dict at: 'model' ifAbsent: [ Dictionary new ].
		type := model at: 'type' ifAbsent: [ nil ].
		merges := model at: 'merges' ifAbsent: [ nil ].
		(type = 'BPE' and: [ merges notNil and: [ merges notEmpty ] ])
			ifTrue: [ ^ GcMergeList fromMergesArray: merges ] ].
	^ GcMergeList fromMergesText: (client getString: (client resolveUrlFor: repositoryId file: 'merges.txt'))
]

{ #category : 'loading' }
GcHuggingFaceModelSource >> loadMetadata [
	"Force-fetch and cache config.json + the default safetensors header over bounded HTTP. NOT called from any render block."
	self config.
	self safetensorsFile.
	^ self
]

{ #category : 'cached access' }
GcHuggingFaceModelSource >> loadedConfig [
	"The cached config, if already fetched -- no network (I5)."
	^ cachedConfig
]

{ #category : 'merge list' }
GcHuggingFaceModelSource >> loadedMergeList [
	"The cached merge list, or nil if not yet loaded (render-safe)."
	^ cachedMergeList
]

{ #category : 'cached access' }
GcHuggingFaceModelSource >> loadedSafetensorsFile [
	"The cached safetensors file, if the header was already fetched -- no network (I5)."
	^ cachedFile
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> loadedUndertrainedScan [
	"The cached undertrained scan, if already computed -- no network (I5)."
	^ cachedUndertrainedScan
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> manifest [
	^ self manifestFor: repositoryId
]

{ #category : 'fetching' }
GcHuggingFaceModelSource >> manifestFor: aRepoId [
	| tree manifest |
	tree := client fileTree: aRepoId.
	manifest := GcRepoManifest new.
	tree do: [ :entry |
		(entry at: 'type' ifAbsent: [ 'file' ]) = 'file' ifTrue: [
			manifest addFile: (GcFileDigest
				path: (entry at: 'path' ifAbsent: [ nil ])
				size: (entry at: 'size' ifAbsent: [ nil ])
				sha256: ((entry at: 'lfs' ifAbsent: [ nil ])
					ifNotNil: [ :lfs | lfs at: 'oid' ifAbsent: [ nil ] ]
					ifNil: [ entry at: 'oid' ifAbsent: [ nil ] ])) ] ].
	^ manifest
]

{ #category : 'merge list' }
GcHuggingFaceModelSource >> mergeList [
	"Cached: the BPE merge list, fetched once per source (force-fetch). NOT from render blocks."
	^ cachedMergeList ifNil: [ cachedMergeList := self loadMergeList ]
]

{ #category : 'printing' }
GcHuggingFaceModelSource >> printOn: aStream [
	aStream nextPutAll: 'GcHuggingFaceModelSource('.
	aStream nextPutAll: (repositoryId ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> repositoryFileNames [
	"The repo's top-level file paths (best-effort; empty on any error), used only to build a helpful 'no safetensors' message."
	^ [ (client fileTree: repositoryId) collect: [ :each | each at: 'path' ] ]
		on: Error
		do: [ :e | #() ]
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> repositoryId [
	^ repositoryId
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> repositoryId: aString [
	repositoryId := aString
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> resolveSafetensorsFile [
	"Resolve the model's safetensors weights. Fast path: the single model.safetensors (unchanged for single-file models). On 404: assemble the sharded union from model.safetensors.index.json (naming-agnostic, shard list = unique weight_map values). If neither exists: a clear domain error naming the safetensors-ish files present."
	| headerString |
	headerString := client safetensorsHeaderStringIfPresent: repositoryId file: 'model.safetensors'.
	headerString ifNotNil: [
		^ self
			buildSafetensorsFileFor: repositoryId
			file: 'model.safetensors'
			header: (Gt4HuggingFaceSafetensorsHeader fromString: headerString) ].
	^ self resolveShardedSafetensorsFile
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> resolveShardedSafetensorsFile [
	"Assemble the sharded union from model.safetensors.index.json. Authoritative shard list = the UNIQUE VALUES of weight_map (naming-agnostic); one header Range read per distinct shard. No index either -> a clear domain error."
	| index |
	index := client safetensorsIndex: repositoryId.
	index ifNil: [ ^ self signalNoSafetensors ].
	^ GcShardedSafetensorsFile
		fromWeightMap: (index at: 'weight_map')
		metadata: (index at: 'metadata' ifAbsent: [ nil ])
		path: repositoryId , '/model.safetensors.index.json'
		shardBuilder: [ :fileName | self safetensorsFileFor: repositoryId file: fileName ]
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> safetensorsFile [
	"The model's safetensors tensors -- the single model.safetensors or the sharded union -- cached: headers fetched once per source."
	^ cachedFile ifNil: [ cachedFile := self resolveSafetensorsFile ]
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> safetensorsFile: aFileName [
	^ self safetensorsFileFor: repositoryId file: aFileName
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> safetensorsFileFor: aRepoId file: aFileName [
	"Fetch one physical safetensors file's header and build a GcSafetensorsFile wired for ranged sampling (I5)."
	^ self
		buildSafetensorsFileFor: aRepoId
		file: aFileName
		header: (client safetensorsHeader: aRepoId file: aFileName)
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> scanUndertrainedTokens [
	"Bounded live convenience scan: take the metadata-anomalous tokens (the 'Odd tokens' lens, capped) as candidates and add embedding-weight evidence. Fetches tokenizer.json + vocab.json + a 256-row control band + one row per candidate. NOT called from any render block."
	| group candidateIds |
	group := self tokenGroup.
	candidateIds := (group anomalousTokens collect: [ :t | t tokenId ]) asArray.
	candidateIds := candidateIds first: (candidateIds size min: 48).
	^ self undertrainedScanForCandidateIds: candidateIds controlBandStart: 0 controlBandSize: 256
]

{ #category : 'safetensors' }
GcHuggingFaceModelSource >> signalNoSafetensors [
	"Neither model.safetensors nor its shard index exist. Delegate the (core, hermetic) message construction, supplying the repo's file list."
	^ GcShardedSafetensorsFile
		signalNoSafetensorsForRepository: repositoryId
		filesPresent: self repositoryFileNames
]

{ #category : 'views' }
GcHuggingFaceModelSource >> sourceFacets [
	^ {
		'Repository' -> repositoryId.
		'Base URL' -> client baseUrl.
		'Token' -> (client hasToken ifTrue: [ 'present' ] ifFalse: [ 'none (public)' ]).
		'Default file' -> 'model.safetensors' }
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> tensorGroup [
	^ self safetensorsFile tensorGroup
]

{ #category : 'convenience' }
GcHuggingFaceModelSource >> tensorTree [
	^ self safetensorsFile tensorTree
]

{ #category : 'accessing' }
GcHuggingFaceModelSource >> tokenGroup [
	"Fetches tokenizer.json once (a few MB over HTTP) and computes anomalous-token metadata from vocab + merges alone, no embeddings or inference."
	| dict model vocab merges specials |
	dict := client getJson: (client resolveUrlFor: repositoryId file: 'tokenizer.json').
	model := dict at: 'model' ifAbsent: [ Dictionary new ].
	vocab := model at: 'vocab' ifAbsent: [ Dictionary new ].
	merges := model at: 'merges' ifAbsent: [ #() ].
	specials := (dict at: 'added_tokens' ifAbsent: [ #() ]) collect: [ :t | t at: 'content' ifAbsent: [ '' ] ].
	^ GcTokenGroup fromVocabulary: vocab merges: merges specialTokens: specials
]

{ #category : 'operations' }
GcHuggingFaceModelSource >> undertrainedScanForCandidateIds: idColl controlBandStart: aStart controlBandSize: aCount [
	"Build (and cache) a GcUndertrainedScan over this model's embedding tensor: fetch vocab.json + one control band of aCount rows + one row per candidate id (I5: bounded ranged reads, never the whole matrix), scoring embedding-norm evidence. Attaches the cached merge list (nil-safe) so the norm scatter can use merge-rank X. NOT called from any render block -- driven by an example or the <gtAction>."
	| file emb lmHead vocab scan |
	file := self safetensorsFile.
	emb := self embeddingTensorIn: file.
	lmHead := self unembeddingTensorIn: file.
	vocab := self vocabIdToText.
	scan := GcUndertrainedScan
		embeddingRef: emb
		unembeddingRef: lmHead
		vocab: vocab
		controlBandStart: aStart
		controlBandSize: aCount
		candidateIds: idColl.
	scan mergeList: self loadedMergeList.
	cachedUndertrainedScan := scan.
	^ scan
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> unembeddingTensorIn: aFile [
	"The output projection (lm_head) tensor, or nil when input/output embeddings are TIED (no separate tensor -- e.g. gpt2, SmolLM2). Tied is the signal that unembedding norm equals embedding norm."
	^ aFile tensors
		detect: [ :t | t name = 'lm_head.weight' or: [ t name endsWith: '.lm_head.weight' ] ]
		ifNone: [ nil ]
]

{ #category : 'undertrained tokens' }
GcHuggingFaceModelSource >> vocabIdToText [
	"id -> token string, from vocab.json (token-string -> id), inverted. One JSON fetch (prefer vocab.json; smaller than tokenizer.json). NOT called from any render block."
	| raw inverted |
	raw := client getJson: (client resolveUrlFor: repositoryId file: 'vocab.json').
	inverted := Dictionary new.
	raw keysAndValuesDo: [ :tokenString :id | inverted at: id put: tokenString ].
	^ inverted
]
