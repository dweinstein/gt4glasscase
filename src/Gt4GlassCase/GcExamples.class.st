"
Executable documentation for Glass Case. Invariant I9: every claim is a <gtExample>. Examples compose (a campaign example references artifact examples), so the dependency graph is explorable and the system is self-documenting; findings become examples and examples become the release-watch regression suite.
"
Class {
	#name : 'GcExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'examples - architecture compare' }
GcExamples >> architectureComparisonMarksDifference [
	<gtExample>
	| a b comparison rows layersRow |
	a := GcArchitecture new numLayers: 30; numHeads: 9; hiddenSize: 576; yourself.
	b := GcArchitecture new numLayers: 32; numHeads: 9; hiddenSize: 576; yourself.
	comparison := GcArchitectureComparison forAll: { 'base' -> a. 'finetune' -> b }.
	rows := comparison facetRows.
	layersRow := rows detect: [ :r | (r at: 1) = 'Layers' ].
	self assert: (layersRow at: 3) equals: false.
	self assert: comparison labels equals: #('base' 'finetune').
	^ comparison
]

{ #category : 'examples - dead weights' }
GcExamples >> architectureDeadWeightsCleanModel [
	<gtExample>
	| arch group analysis |
	arch := GcArchitecture new numLayers: 2; yourself.
	group := GcTensorGroup new.
	arch expectedTensorNames do: [ :n | group addItem: (GcTensorRef name: n dtype: #bf16 shape: #(4 4)) ].
	analysis := arch deadWeightAnalysisOn: group.
	self assert: (analysis at: #unreferenced) isEmpty.
	self assert: (analysis at: #missing) isEmpty.
	self assert: (analysis at: #matchedCount) equals: group size.
	^ analysis
]

{ #category : 'examples - dead weights' }
GcExamples >> architectureDeadWeightsFindsImplantAndMissing [
	<gtExample>
	| arch group analysis |
	arch := GcArchitecture new numLayers: 2; yourself.
	group := GcTensorGroup new.
	arch expectedTensorNames do: [ :n |
		n = 'model.norm.weight' ifFalse: [ group addItem: (GcTensorRef name: n dtype: #bf16 shape: #(4 4)) ] ].
	group addItem: (GcTensorRef name: 'model.layers.1.mlp.implant.weight' dtype: #bf16 shape: #(4 4)).
	analysis := arch deadWeightAnalysisOn: group.
	self assert: (analysis at: #unreferenced) size equals: 1.
	self assert: (analysis at: #unreferenced) first name equals: 'model.layers.1.mlp.implant.weight'.
	self assert: (analysis at: #missing) equals: { 'model.norm.weight' }.
	^ analysis
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupPartitionByPrecision [
	<gtExample>
	| group partitions |
	group := self artifactGroupThreePrecisions.
	partitions := group partitionBy: [ :a | a precision ].
	self assert: (partitions isKindOf: GcGroupOfGroups).
	self assert: partitions size equals: 3.
	self assert: (partitions items allSatisfy: [ :g | g isKindOf: GcArtifactGroup ]).
	^ partitions
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupSelectReturnsGroup [
	<gtExample>
	"I2 + I3: select: returns a same-species group that records how it was made."
	| group selected |
	group := self artifactGroupThreePrecisions.
	selected := group select: [ :a | a precision = #bf16 ].
	self assert: (selected isKindOf: GcArtifactGroup).
	self assert: selected size equals: 1.
	self assert: selected derivation operation equals: #select:.
	self assert: selected derivation parent == group.
	^ selected
]

{ #category : 'examples-groups' }
GcExamples >> artifactGroupThreePrecisions [
	<gtExample>
	| revision group |
	revision := self revisionQwen3_32b.
	group := GcArtifactGroup new.
	#(#bf16 #int8 #int4) do: [ :prec |
		group addItem: (GcModelArtifact revision: revision precision: prec) ].
	self assert: group size equals: 3.
	self assert: (group isKindOf: GcArtifactGroup).
	^ group
]

{ #category : 'examples-provenance' }
GcExamples >> artifactQwen3_32bBf16 [
	<gtExample>
	| artifact |
	artifact := GcModelArtifact
		revision: self revisionQwen3_32b
		precision: #bf16
		format: #safetensors
		location: 'hf://Qwen/Qwen3-32B'.
	self assert: artifact precision equals: #bf16.
	self assert: (artifact coordinate at: #precision) equals: #bf16.
	^ artifact
]

{ #category : 'examples-groups' }
GcExamples >> artifactSliceByPrecision [
	<gtExample>
	"varyingAxis: groups cohorts differing only along precision; the three artifacts share a revision so they form one cohort."
	| group slice |
	group := self artifactGroupThreePrecisions.
	slice := group varyingAxis: #precision.
	self assert: (slice isKindOf: GcSliceGroup).
	self assert: slice varyingAxis equals: #precision.
	self assert: slice cohorts size equals: 1.
	self assert: slice cohorts anyOne size equals: 3.
	^ slice
]

{ #category : 'examples - coverage' }
GcExamples >> campaignPlanCoverage [
	<gtExample>
	| coords plan campaign |
	coords := OrderedCollection new.
	#(bf16 int8) do: [ :prec |
		#(p1 p2) do: [ :probe |
			coords add: (GcCoordinate new at: #precision put: prec; at: #probe put: probe; yourself) ] ].
	plan := GcCampaignPlan new plannedCoordinates: coords; yourself.
	campaign := GcCampaign new name: 'pilot'; plan: plan; yourself.
	self assert: campaign plannedCoordinates size equals: 4.
	self assert: campaign printString equals: 'campaign pilot (4 planned coordinates)'.
	^ campaign
]

{ #category : 'examples - small multiples' }
GcExamples >> comparisonSideBySideRows [
	<gtExample>
	| comparison rows |
	comparison := self groupComparisonSharedAndUnique.
	rows := comparison sideBySideRows.
	self assert: (rows first at: 1) equals: 'Items'.
	self assert: ((rows second at: 5) isKindOf: GcGroup).
	self assert: (rows second at: 5) size equals: 1.
	^ rows
]

{ #category : 'examples' }
GcExamples >> comparisonSwapMirrorsSides [
	<gtExample>
	| comparison swapped |
	comparison := self groupComparisonSharedAndUnique.
	swapped := GcGroupComparison left: comparison right right: comparison left.
	self assert: swapped left == comparison right.
	self assert: swapped right == comparison left.
	self assert: swapped onlyInLeft size equals: comparison onlyInRight size.
	self assert: swapped onlyInRight size equals: comparison onlyInLeft size.
	self assert: swapped inBoth size equals: comparison inBoth size.
	^ swapped
]

{ #category : 'examples-groups' }
GcExamples >> completionGroupSampleIsReproducible [
	<gtExample>
	"A seeded sample is reproducible and records its seed on the derivation (I3)."
	| group sampleA sampleB |
	group := GcCompletionGroup new.
	1 to: 10 do: [ :i |
		group addItem: (GcCompletion run: nil text: 'completion ', i printString) ].
	sampleA := group sample: 3 seed: 7.
	sampleB := group sample: 3 seed: 7.
	self assert: sampleA size equals: 3.
	self assert: (sampleA items collect: [ :c | c text ]) equals: (sampleB items collect: [ :c | c text ]).
	self assert: (sampleA derivation parameterAt: #seed) equals: 7.
	^ sampleA
]

{ #category : 'examples-hypercube' }
GcExamples >> coordinateHoldsAxes [
	<gtExample>
	| coord reduced |
	coord := GcCoordinate new
		at: #precision put: #bf16;
		at: #seed put: 0;
		yourself.
	reduced := coord withoutAxis: #seed.
	self assert: reduced axes equals: #(#precision).
	^ coord
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderBf16KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder bf16FromU16: 16r3F80) equals: 1.0.
	self assert: (GcDtypeDecoder bf16FromU16: 16rC000) equals: -2.0.
	decoder := GcDtypeDecoder forDtype: #bf16.
	self assert: (decoder decodeBytes: #[16r80 16r3F 16r00 16rC0]) equals: { 1.0. -2.0 }.
	self assert: decoder bytesPerElement equals: 2.
	^ decoder
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderF16KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder f16FromU16: 16r3C00) equals: 1.0.
	self assert: (GcDtypeDecoder f16FromU16: 16r4000) equals: 2.0.
	self assert: (GcDtypeDecoder f16FromU16: 16rC000) equals: -2.0.
	self assert: (GcDtypeDecoder f16FromU16: 16r0001) equals: (2 raisedTo: -24) asFloat.
	self assert: (GcDtypeDecoder f16FromU16: 16r7C00) isInfinite.
	self assert: (GcDtypeDecoder f16FromU16: 16r7C00) positive.
	self assert: (GcDtypeDecoder f16FromU16: 16rFC00) isInfinite.
	self assert: (GcDtypeDecoder f16FromU16: 16rFC00) negative.
	self assert: (GcDtypeDecoder f16FromU16: 16r7E00) isNaN.
	decoder := GcDtypeDecoder forDtype: #f16.
	self assert: (decoder decodeBytes: #[16r00 16r3C 16r00 16r40]) equals: { 1.0. 2.0 }.
	^ decoder
]

{ #category : 'examples - tensor numerics' }
GcExamples >> dtypeDecoderF32KnownValues [
	<gtExample>
	| decoder |
	self assert: (GcDtypeDecoder f32FromU32: 16r3F800000) equals: 1.0.
	self assert: (GcDtypeDecoder f32FromU32: 16rC0000000) equals: -2.0.
	decoder := GcDtypeDecoder forDtype: #f32.
	self assert: (decoder decodeBytes: #[16r00 16r00 16r80 16r3F 16r00 16r00 16r00 16rC0]) equals: { 1.0. -2.0 }.
	self assert: decoder bytesPerElement equals: 4.
	^ decoder
]

{ #category : 'examples-provenance' }
GcExamples >> fileDigestConfigJson [
	<gtExample>
	| digest |
	digest := GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222'.
	self assert: digest shortSha256 equals: 'aaaa1111bbbb'.
	^ digest
]

{ #category : 'examples-groups' }
GcExamples >> groupComparisonSharedAndUnique [
	<gtExample>
	| revision a b c left right comparison |
	revision := self revisionQwen3_32b.
	a := GcModelArtifact revision: revision precision: #bf16.
	b := GcModelArtifact revision: revision precision: #int8.
	c := GcModelArtifact revision: revision precision: #int4.
	left := GcArtifactGroup withAll: { a. b }.
	right := GcArtifactGroup withAll: { b. c }.
	comparison := left compareTo: right.
	self assert: comparison inBoth size equals: 1.
	self assert: comparison onlyInLeft size equals: 1.
	self assert: comparison onlyInRight size equals: 1.
	^ comparison
]

{ #category : 'examples-groups' }
GcExamples >> groupDerivationChain [
	<gtExample>
	"Lineage is never broken (I3): chained operations are walkable back to the root."
	| group leaf |
	group := self artifactGroupThreePrecisions.
	leaf := (group select: [ :a | a precision ~= #int4 ]) select: [ :a | a precision = #bf16 ].
	self assert: leaf derivationChain equals: (OrderedCollection withAll: #(#select: #select:)).
	^ leaf
]

{ #category : 'examples-groups' }
GcExamples >> groupOutliersByByteSize [
	<gtExample>
	"outliersBy: keeps only items more than 2 std devs from the mean, lineage preserved."
	| group sizes outliers |
	group := GcTensorGroup new.
	sizes := #(100 110 105 95 100 108 97 103 102 1000000).
	sizes doWithIndex: [ :sz :i |
		| t |
		t := GcTensorRef name: ('model.layers.0.mlp.w', i printString, '.weight') dtype: #bf16 shape: #(1).
		t beginOffset: 0.
		t endOffset: sz.
		group addItem: t ].
	outliers := group outliersBy: [ :t | t byteSize ].
	self assert: outliers size equals: 1.
	self assert: (outliers isKindOf: GcTensorGroup).
	^ outliers
]

{ #category : 'examples - small multiples' }
GcExamples >> groupSmallMultiplesRendersCohorts [
	<gtExample>
	| partitions stencil context cell |
	partitions := self tensorGroupPartitionByModule.
	stencil := GcCohortStencil default.
	context := stencil contextFor: partitions.
	self assert: (context at: #max) >= 1.0.
	cell := stencil elementFor: partitions items first context: context.
	self assert: (cell isKindOf: BlElement).
	^ partitions
]

{ #category : 'examples-provenance' }
GcExamples >> manifestDriftDetectsTampering [
	<gtExample>
	| clean tampered drift |
	clean := self manifestQwen3.
	tampered := GcRepoManifest revision: self revisionQwen3_32b.
	tampered addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	tampered addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'deadbeefdeadbeef').
	drift := clean driftFrom: tampered.
	self assert: drift size equals: 1.
	self assert: drift first path equals: 'model.safetensors.index.json'.
	^ drift
]

{ #category : 'examples-provenance' }
GcExamples >> manifestDriftIsEmpty [
	<gtExample>
	| a b |
	a := self manifestQwen3.
	b := self manifestQwen3.
	self assert: (a driftFrom: b) isEmpty.
	^ a
]

{ #category : 'examples - manifest drift' }
GcExamples >> manifestDriftReportFindsSilentReupload [
	<gtExample>
	| clean tampered report |
	clean := self manifestQwen3.
	tampered := GcRepoManifest revision: self revisionQwen3_32b.
	tampered addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	tampered addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'deadbeefdeadbeef').
	report := tampered driftReportFrom: clean.
	self assert: report isClean not.
	self assert: report changedFiles size equals: 1.
	self assert: report addedFiles isEmpty.
	self assert: report removedFiles isEmpty.
	^ report
]

{ #category : 'examples - manifest drift' }
GcExamples >> manifestDriftReportIsCleanForIdenticalSnapshots [
	<gtExample>
	| report |
	report := self manifestQwen3 driftReportFrom: self manifestQwen3.
	self assert: report isClean.
	self assert: report printString equals: 'clean drift (2 files)'.
	^ report
]

{ #category : 'examples-provenance' }
GcExamples >> manifestQwen3 [
	<gtExample>
	| manifest |
	manifest := GcRepoManifest revision: self revisionQwen3_32b.
	manifest addFile: (GcFileDigest path: 'config.json' size: 812 sha256: 'aaaa1111bbbb2222').
	manifest addFile: (GcFileDigest path: 'model.safetensors.index.json' size: 42318 sha256: 'cccc3333dddd4444').
	self assert: manifest fileCount equals: 2.
	self assert: manifest totalSize equals: 43130.
	^ manifest
]

{ #category : 'examples-provenance' }
GcExamples >> modelFamilyQwen3 [
	<gtExample>
	| family |
	family := GcModelFamily name: 'Qwen3-32B' publisher: 'Alibaba'.
	self assert: family name equals: 'Qwen3-32B'.
	^ family
]

{ #category : 'examples-hypercube' }
GcExamples >> precisionAxis [
	<gtExample>
	| axis |
	axis := GcAxis
		named: #precision
		values: #(#bf16 #int8 #int4 #int3)
		ordering: #(#bf16 #int8 #int4 #int3).
	self assert: axis isOrdinal.
	self assert: (axis rankOf: #int4) equals: 3.
	^ axis
]

{ #category : 'examples-provenance' }
GcExamples >> provenanceQwen3 [
	<gtExample>
	| prov |
	prov := GcProvenance publisher: 'Alibaba' license: 'Apache-2.0'.
	prov announcementUrl: 'https://qwenlm.github.io/'.
	self assert: prov publisher equals: 'Alibaba'.
	^ prov
]

{ #category : 'examples-provenance' }
GcExamples >> revisionQwen3_32b [
	<gtExample>
	| revision |
	revision := GcModelRevision
		repository: 'Qwen/Qwen3-32B'
		commit: 'a1b2c3d4e5'
		family: self modelFamilyQwen3.
	self assert: revision id equals: 'Qwen/Qwen3-32B@a1b2c3d4e5'.
	^ revision
]

{ #category : 'examples-provenance' }
GcExamples >> revisionWithProvenance [
	<gtExample>
	| revision |
	revision := self revisionQwen3_32b.
	revision provenance: self provenanceQwen3.
	self assert: revision provenance license equals: 'Apache-2.0'.
	^ revision
]

{ #category : 'examples - slack space' }
GcExamples >> safetensorsSlackGapAndOverlap [
	<gtExample>
	| h file ranges |
	h := Dictionary new.
	h at: 'a' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(0 16); yourself).
	h at: 'b' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(32 64); yourself).
	h at: 'c' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(48 80); yourself).
	file := GcSafetensorsFile new.
	file path: 'example-slack'.
	file parseHeaderDictionary: h.
	ranges := file slackRanges.
	self assert: ranges size equals: 2.
	self assert: ranges first kind equals: #gap.
	self assert: ranges first byteSize equals: 16.
	self assert: (ranges at: 2) kind equals: #overlap.
	^ file
]

{ #category : 'examples - slack space' }
GcExamples >> safetensorsTightFileHasNoSlack [
	<gtExample>
	| h file |
	h := Dictionary new.
	h at: 'a' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(0 16); yourself).
	h at: 'b' put: (Dictionary new at: 'dtype' put: 'F32'; at: 'shape' put: #(2 2); at: 'data_offsets' put: #(16 32); yourself).
	file := GcSafetensorsFile new.
	file path: 'example-tight'.
	file parseHeaderDictionary: h.
	self assert: file slackRanges isEmpty.
	^ file
]

{ #category : 'examples-groups' }
GcExamples >> tensorGroupPartitionByModule [
	<gtExample>
	| group partitions |
	group := GcTensorGroup new.
	group addItem: (GcTensorRef name: 'model.layers.0.self_attn.q_proj.weight' dtype: #bf16 shape: #(4096 4096)).
	group addItem: (GcTensorRef name: 'model.layers.0.self_attn.k_proj.weight' dtype: #bf16 shape: #(4096 1024)).
	group addItem: (GcTensorRef name: 'model.layers.0.mlp.gate_proj.weight' dtype: #bf16 shape: #(4096 14336)).
	partitions := group partitionBy: [ :t | t module ].
	self assert: partitions size equals: 3.
	^ partitions
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorHistogramBinMath [
	<gtExample>
	| stats hist total |
	stats := GcTensorStats fromValues: { 0.0. 0.0. 10.0 }.
	hist := stats histogram.
	self assert: hist size equals: 40.
	self assert: hist first count equals: 2.
	self assert: hist last count equals: 1.
	total := hist inject: 0 into: [ :acc :bin | acc + bin count ].
	self assert: total equals: 3.
	self assert: hist first lowerBound equals: 0.0.
	self assert: hist last upperBound equals: 10.0.
	^ stats
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorHistogramDegenerateSingleBin [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 2.0. 2.0. 2.0 }.
	self assert: stats histogram size equals: 1.
	self assert: stats histogram first count equals: 3.
	self assert: stats min equals: 2.0.
	self assert: stats max equals: 2.0.
	self assert: stats std equals: 0.0.
	^ stats
]

{ #category : 'examples-groups' }
GcExamples >> tensorNameParsesMoe [
	<gtExample>
	| name |
	name := GcTensorName from: 'model.layers.3.mlp.experts.7.gate_proj.weight'.
	self assert: name layerIndex equals: 3.
	self assert: name module equals: 'gate_proj'.
	self assert: name role equals: 'weight'.
	self assert: name block equals: #mlp.
	self assert: name expertIndex equals: 7.
	self assert: name isExpert.
	^ name
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorSliceReportsSampledProvenance [
	<gtExample>
	| ref slice fullSlice |
	ref := GcTensorRef name: 'model.embed_tokens.weight' dtype: #bf16 shape: #(100 10).
	slice := GcTensorSlice tensorRef: ref elementStart: 0 values: ((1 to: 64) collect: [ :i | i asFloat ]) isFull: false.
	self assert: slice sampleCount equals: 64.
	self assert: slice totalCount equals: 1000.
	self assert: slice isSampled.
	self assert: slice provenanceLabel equals: 'sampled 64 of 1,000'.
	fullSlice := GcTensorSlice fromValues: { 1.0. 2.0. 3.0 }.
	self assert: fullSlice isFull.
	self assert: fullSlice provenanceLabel equals: 'full 3 of 3'.
	^ slice
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorStatsCountsNanInfAndZeros [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 0.0. 0.0. 2.0. Float nan. Float infinity. Float negativeInfinity }.
	self assert: stats sampleCount equals: 6.
	self assert: stats nanCount equals: 1.
	self assert: stats infCount equals: 2.
	self assert: stats zeroFraction equals: (2 / 6) asFloat.
	self assert: stats mean equals: (2 / 3) asFloat.
	self assert: stats min equals: 0.0.
	self assert: stats max equals: 2.0.
	self assert: stats healthLabel equals: 'NaN present (1)'.
	^ stats
]

{ #category : 'examples - tensor numerics' }
GcExamples >> tensorStatsOverSyntheticValues [
	<gtExample>
	| stats |
	stats := GcTensorStats fromValues: { 1.0. 2.0. 3.0. 4.0. 5.0 }.
	self assert: stats mean equals: 3.0.
	self assert: stats min equals: 1.0.
	self assert: stats max equals: 5.0.
	self assert: (stats std closeTo: 2 sqrt).
	self assert: (stats l2Norm closeTo: 55 sqrt).
	self assert: stats nanCount equals: 0.
	self assert: stats infCount equals: 0.
	self assert: stats zeroFraction equals: 0.0.
	self assert: stats sampleCount equals: 5.
	self assert: stats totalCount equals: 5.
	^ stats
]

{ #category : 'examples - twin check' }
GcExamples >> tensorTwinCheckAcceptsPrecisionPair [
	<gtExample>
	| leftG rightG comparison |
	leftG := GcTensorGroup new.
	leftG addItem: (GcTensorRef name: 'x.weight' dtype: #bf16 shape: #(4 4)).
	leftG addItem: (GcTensorRef name: 'y.weight' dtype: #bf16 shape: #(8 4)).
	rightG := GcTensorGroup new.
	rightG addItem: (GcTensorRef name: 'x.weight' dtype: #int8 shape: #(4 4)).
	rightG addItem: (GcTensorRef name: 'y.weight' dtype: #int8 shape: #(8 4)).
	comparison := leftG compareTo: rightG.
	self assert: (comparison twinCheckVerdict beginsWith: 'structural twins').
	^ comparison
]

{ #category : 'examples - twin check' }
GcExamples >> tensorTwinCheckDetectsMismatch [
	<gtExample>
	| leftG rightG comparison |
	leftG := GcTensorGroup new.
	leftG addItem: (GcTensorRef name: 'x.weight' dtype: #bf16 shape: #(4 4)).
	leftG addItem: (GcTensorRef name: 'y.weight' dtype: #bf16 shape: #(4 4)).
	rightG := GcTensorGroup new.
	rightG addItem: (GcTensorRef name: 'x.weight' dtype: #int8 shape: #(4 4)).
	rightG addItem: (GcTensorRef name: 'y.weight' dtype: #int8 shape: #(4 2)).
	comparison := leftG compareTo: rightG.
	self assert: (comparison twinCheckVerdict beginsWith: 'NOT twins').
	self assert: ((comparison twinCheckRows collect: [ :r | r at: 1 ]) includes: #shapeMismatch).
	^ comparison
]

{ #category : 'examples' }
GcExamples >> tokenGroupAnomalousOnlyDerivation [
	<gtExample>
	| group anomalous |
	group := self tokenGroupFlagsTriggerCandidates.
	anomalous := group withItems: group anomalousTokens derivedBy: #anomalous.
	self assert: (anomalous isKindOf: GcTokenGroup).
	self assert: anomalous size equals: group anomalousTokens size.
	self assert: anomalous size equals: 4.
	self assert: (anomalous items allSatisfy: [ :t | t isAnomalous ]).
	self assert: anomalous derivation operation equals: #anomalous.
	^ anomalous
]

{ #category : 'examples - token lens' }
GcExamples >> tokenGroupFlagsTriggerCandidates [
	<gtExample>
	| vocab merges specials group magikarp |
	vocab := Dictionary new.
	vocab at: 'h' put: 1.
	vocab at: 'e' put: 2.
	vocab at: 'hello' put: 3.
	vocab at: 'SolidGoldMagikarp' put: 4.
	vocab at: '<0x0A>' put: 5.
	vocab at: '<|reserved_42|>' put: 6.
	vocab at: '<|endoftext|>' put: 7.
	merges := { 'he llo' }.
	specials := { '<|endoftext|>' }.
	group := GcTokenGroup fromVocabulary: vocab merges: merges specialTokens: specials.
	self assert: group size equals: 7.
	self assert: group anomalousTokens size equals: 4.
	magikarp := group items detect: [ :t | t tokenId = 4 ].
	self assert: (magikarp hasFlag: #unreachable).
	self assert: (group statistics at: #anomalous) equals: 4.
	^ group
]

{ #category : 'examples-provenance' }
GcExamples >> tokenizerSketch [
	<gtExample>
	| tok |
	tok := GcTokenizer vocabSize: 151936.
	self assert: tok vocabSize equals: 151936.
	^ tok
]

{ #category : 'examples' }
GcExamples >> vocabTokenDetailFacets [
	<gtExample>
	| token facets |
	token := GcVocabToken id: 42 text: 'SolidGoldMagikarp'.
	token addFlag: #unreachable.
	facets := token detailFacets.
	self assert: (facets collect: [ :assoc | assoc key ]) asArray
		equals: #('Id' 'Text' 'Rendered' 'UTF-8 bytes' 'Length' 'Flags').
	self assert: (facets detect: [ :assoc | assoc key = 'Id' ]) value equals: 42.
	self assert: (facets detect: [ :assoc | assoc key = 'Length' ]) value equals: 17.
	self assert: ((facets detect: [ :assoc | assoc key = 'Flags' ]) value includesSubstring: 'unreachable').
	self assert: token isAnomalous.
	^ token
]
