"
A Mixture-of-Experts top-k gating router as a geometry object. Wraps the decoded E x d router weight matrix W (each of `expertCount` rows is a `hiddenSize`-vector), an optional bias (routers are usually bias-free), and provenance (layerId, sourceLabel, quantizationLabel). Top-k gating is an argmax of linear functions W.h, so the router EXACTLY tessellates hidden space into per-expert convex regions -- the part of an LLM where ReLU/argmax folding is exact. Decoding the matrix from a GcTensorRef is a single ranged read (fromTensorRef:); everything after (logits, argmax, principal singular slice via power iteration, simulated-quantization) is pure CPU and safe inside views (I5: never re-reads bytes in a view). `quantizedToBits:` returns a router with simulated symmetric round-to-nearest weights -- a MECHANISM demonstration, NOT the model's real GGUF codebook.
"
Class {
	#name : 'GcMoeRouter',
	#superclass : 'Object',
	#instVars : [
		'tensorRef',
		'weightMatrix',
		'expertCount',
		'hiddenSize',
		'bias',
		'layerId',
		'sourceLabel',
		'quantizationLabel',
		'cachedPrincipalMap'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcMoeRouter class >> fromTensorRef: aTensorRef [
	"Decode the whole E x d router weight tensor with ONE ranged read (I5: the only network touch; never inside a view) and reshape it row-major into E expert rows. Provenance comes from the tensor name."
	| dims expertsCount hidden slice flat rows |
	dims := aTensorRef dimensions.
	dims size = 2 ifFalse: [ ^ self error: 'Router tensor must be rank 2 (experts x hidden), got ' , dims printString ].
	expertsCount := dims first.
	hidden := dims second.
	slice := aTensorRef sliceFromElement: 0 count: aTensorRef elementCount.
	flat := slice values.
	rows := (0 to: expertsCount - 1) collect: [ :e | flat copyFrom: e * hidden + 1 to: e * hidden + hidden ].
	^ self new
		setWeightMatrix: rows expertCount: expertsCount hiddenSize: hidden;
		tensorRef: aTensorRef;
		layerId: aTensorRef layerIndex;
		sourceLabel: aTensorRef name;
		yourself
]

{ #category : 'instance creation' }
GcMoeRouter class >> weightMatrix: rows expertCount: anExpertCount hiddenSize: aHiddenSize [
	"Build a router directly from an E x d matrix of rows (each row a d-element Array). For synthetic/hermetic use."
	^ self new
		setWeightMatrix: rows expertCount: anExpertCount hiddenSize: aHiddenSize;
		yourself
]

{ #category : 'accessing' }
GcMoeRouter >> bias [
	^ bias
]

{ #category : 'accessing' }
GcMoeRouter >> bias: aVectorOrNil [
	bias := aVectorOrNil
]

{ #category : 'defaults' }
GcMoeRouter >> defaultResolution [
	"Grid steps per slice axis. 160 x 160 x expertCount stays well under a few million flops."
	^ 160
]

{ #category : 'math - private' }
GcMoeRouter >> dot: aVector with: anotherVector [
	| sum |
	sum := 0.0.
	1 to: aVector size do: [ :i | sum := sum + ((aVector at: i) * (anotherVector at: i)) ].
	^ sum
]

{ #category : 'accessing' }
GcMoeRouter >> dtypeLabel [
	^ tensorRef ifNil: [ 'constructed (in-image)' ] ifNotNil: [ :t | t dtype printString ]
]

{ #category : 'accessing' }
GcMoeRouter >> expertCount [
	^ expertCount
]

{ #category : 'gt - views' }
GcMoeRouter >> gtExpertRegionsFor: aView [
	"The router's argmax tessellation on its principal slice (pure CPU over the decoded matrix; no network)."
	<gtView>
	^ aView forward
		title: 'Expert regions';
		priority: 5;
		object: [ self principalRegionMap ];
		view: #gtExpertRegionsFor:
]

{ #category : 'gt - views' }
GcMoeRouter >> gtQuantizationShiftFor: aView [
	"How much this router's routing moves under simulated int4 RTN, on its principal slice."
	<gtView>
	^ aView forward
		title: 'Quantization shift';
		priority: 7;
		object: [ self principalRegionMap ];
		view: #gtQuantizationShiftFor:
]

{ #category : 'gt - views' }
GcMoeRouter >> gtRouterFacetsFor: aView [
	"Provenance and shape of this router. Rows send the region map / values."
	<gtView>
	^ aView columnedList
		title: 'Router';
		priority: 20;
		items: [ self routerFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcMoeRouter >> gtRoutingSurfaceFor: aView [
	"The router's folded max-logit surface on its principal slice."
	<gtView>
	^ aView forward
		title: 'Routing surface';
		priority: 6;
		object: [ self principalRegionMap ];
		view: #gtRoutingSurfaceFor:
]

{ #category : 'accessing' }
GcMoeRouter >> hiddenSize [
	^ hiddenSize
]

{ #category : 'testing' }
GcMoeRouter >> isQuantized [
	^ quantizationLabel notNil
]

{ #category : 'accessing' }
GcMoeRouter >> layerId [
	^ layerId
]

{ #category : 'accessing' }
GcMoeRouter >> layerId: anObject [
	layerId := anObject
]

{ #category : 'accessing' }
GcMoeRouter >> layerLabel [
	^ layerId ifNil: [ 'n/a' ] ifNotNil: [ :i | i printString ]
]

{ #category : 'math' }
GcMoeRouter >> logitsFor: aHiddenVector [
	"Router logits W.h (+ bias) -- an expertCount-vector."
	^ (1 to: expertCount) collect: [ :e |
		| logit |
		logit := self dot: (weightMatrix at: e) with: aHiddenVector.
		bias ifNotNil: [ logit := logit + (bias at: e) ].
		logit ]
]

{ #category : 'math' }
GcMoeRouter >> matrixTimesVector: aHiddenVector [
	"W . x : an expertCount-vector of per-expert dot products. Cost E*d."
	^ weightMatrix collect: [ :row | self dot: row with: aHiddenVector ]
]

{ #category : 'math - private' }
GcMoeRouter >> norm: aVector [
	^ (self dot: aVector with: aVector) sqrt
]

{ #category : 'math - private' }
GcMoeRouter >> normalized: aVector [
	| n |
	n := self norm: aVector.
	n = 0 ifTrue: [ ^ aVector ].
	^ aVector collect: [ :each | each / n ]
]

{ #category : 'math - private' }
GcMoeRouter >> orthogonalize: aVector against: aCollectionOfDirections [
	"Gram-Schmidt: subtract the projection of aVector onto each (unit) direction."
	| residual |
	residual := aVector.
	aCollectionOfDirections do: [ :d |
		| c |
		c := self dot: residual with: d.
		residual := (1 to: residual size) collect: [ :i | (residual at: i) - (c * (d at: i)) ] ].
	^ residual asArray
]

{ #category : 'math' }
GcMoeRouter >> principalDirections: k [
	"The top-k right singular vectors of W (the hidden-space directions the router is most sensitive to), by power iteration on M = W^T W with M.x = W^T (W x) and Gram-Schmidt deflation. Returns an Array of k orthonormal d-vectors."
	| directions iterations |
	directions := OrderedCollection new.
	iterations := 40.
	1 to: k do: [ :which |
		| x |
		x := self seedVector.
		iterations timesRepeat: [
			| mx |
			mx := self transposeTimesVector: (self matrixTimesVector: x).
			mx := self orthogonalize: mx against: directions.
			x := self normalized: mx ].
		directions add: (self normalized: (self orthogonalize: x against: directions)) ].
	^ directions asArray
]

{ #category : 'geometry' }
GcMoeRouter >> principalRegionMap [
	"The tessellation of this router's principal slice, cached (pure CPU, safe in views)."
	^ cachedPrincipalMap ifNil: [ cachedPrincipalMap := GcRouterRegionMap router: self slice: self principalSlice ]
]

{ #category : 'geometry' }
GcMoeRouter >> principalSlice [
	"A 2D slice through the origin spanned by the top-2 right singular vectors of W, extent scaled to the top singular value so the interesting structure is in-frame."
	| directions sigma1 |
	directions := self principalDirections: 2.
	sigma1 := self singularValueAlong: (directions at: 1).
	^ GcHiddenSlice
		u: (directions at: 1)
		v: (directions at: 2)
		base: (Array new: hiddenSize withAll: 0.0)
		extent: (sigma1 = 0 ifTrue: [ 1.0 ] ifFalse: [ sigma1 ])
		resolution: self defaultResolution
		basisLabel: 'top-2 right singular vectors of W (power iteration on W^T W)'
]

{ #category : 'printing' }
GcMoeRouter >> printOn: aStream [
	aStream
		nextPutAll: 'GcMoeRouter(L';
		nextPutAll: self layerLabel;
		nextPutAll: ', ';
		print: expertCount;
		nextPutAll: ' experts x ';
		print: hiddenSize;
		nextPutAll: 'd';
		nextPutAll: (self isQuantized ifTrue: [ ', quantized' ] ifFalse: [ '' ]);
		nextPutAll: ')'
]

{ #category : 'accessing' }
GcMoeRouter >> quantizationLabel [
	^ quantizationLabel
]

{ #category : 'accessing' }
GcMoeRouter >> quantizationLabel: aString [
	quantizationLabel := aString
]

{ #category : 'quantization' }
GcMoeRouter >> quantizedToBits: nBits [
	"A NEW router whose weights are simulated symmetric round-to-nearest to nBits, PER ROW (each expert row quantized with its own scale = maxAbs(row)/(2^(nBits-1)-1)). This is a MECHANISM demonstration of quantization-conditional routing shift -- NOT the model's real GGUF codebook. Bias (if any) is left in full precision."
	| levels newRows |
	levels := (2 raisedTo: nBits - 1) - 1.
	newRows := weightMatrix collect: [ :row |
		| maxAbs scale |
		maxAbs := row inject: 0.0 into: [ :m :x | m max: x abs ].
		scale := maxAbs = 0 ifTrue: [ 1.0 ] ifFalse: [ maxAbs / levels ].
		row collect: [ :x | (((x / scale) rounded max: levels negated) min: levels) * scale ] ].
	^ GcMoeRouter new
		setWeightMatrix: newRows expertCount: expertCount hiddenSize: hiddenSize;
		tensorRef: tensorRef;
		bias: bias;
		layerId: layerId;
		sourceLabel: sourceLabel;
		quantizationLabel: 'simulated symmetric int' , nBits printString , ' RTN (per-row) -- NOT the real GGUF codebook';
		yourself
]

{ #category : 'gt - facets' }
GcMoeRouter >> routerFacets [
	^ OrderedCollection new
		add: 'Layer' -> self layerLabel;
		add: 'Experts (E)' -> expertCount;
		add: 'Hidden size (d)' -> hiddenSize;
		add: 'Source' -> (sourceLabel ifNil: [ '-' ]);
		add: 'Dtype' -> self dtypeLabel;
		add: 'Has bias' -> bias notNil;
		add: 'Quantization' -> (quantizationLabel ifNil: [ 'none (as decoded)' ]);
		add: 'Principal region map' -> self principalRegionMap;
		yourself
]

{ #category : 'math - private' }
GcMoeRouter >> seedVector [
	"A deterministic (seed-42) unit start vector so power iteration is reproducible across runs."
	| rng x |
	rng := Random seed: 42.
	x := (1 to: hiddenSize) collect: [ :i | rng next - 0.5 ].
	^ self normalized: x
]

{ #category : 'initialization' }
GcMoeRouter >> setWeightMatrix: rows expertCount: anExpertCount hiddenSize: aHiddenSize [
	weightMatrix := rows asArray.
	expertCount := anExpertCount.
	hiddenSize := aHiddenSize
]

{ #category : 'math' }
GcMoeRouter >> singularValueAlong: aDirection [
	"The singular value sigma = ||W . dir|| for a unit direction (how strongly the router responds along dir)."
	^ self norm: (self matrixTimesVector: aDirection)
]

{ #category : 'geometry' }
GcMoeRouter >> sliceForDirectionIndices: aPairOfIndices [
	"A 2D slice from a chosen pair of singular directions (1-based), e.g. #(1 3) to escape a degenerate principal slice."
	| directions chosen sigma |
	directions := self principalDirections: (aPairOfIndices max).
	chosen := aPairOfIndices collect: [ :i | directions at: i ].
	sigma := self singularValueAlong: (chosen at: 1).
	^ GcHiddenSlice
		u: (chosen at: 1)
		v: (chosen at: 2)
		base: (Array new: hiddenSize withAll: 0.0)
		extent: (sigma = 0 ifTrue: [ 1.0 ] ifFalse: [ sigma ])
		resolution: self defaultResolution
		basisLabel: 'right singular vectors ' , aPairOfIndices printString , ' of W'
]

{ #category : 'accessing' }
GcMoeRouter >> sourceLabel [
	^ sourceLabel
]

{ #category : 'accessing' }
GcMoeRouter >> sourceLabel: aString [
	sourceLabel := aString
]

{ #category : 'accessing' }
GcMoeRouter >> tensorRef [
	^ tensorRef
]

{ #category : 'accessing' }
GcMoeRouter >> tensorRef: aTensorRef [
	tensorRef := aTensorRef
]

{ #category : 'math' }
GcMoeRouter >> topExpertFor: aHiddenVector [
	"The 1-based index of the argmax (winning top-1 expert) for hidden vector h."
	| logits best bestIndex |
	logits := self logitsFor: aHiddenVector.
	best := logits at: 1.
	bestIndex := 1.
	2 to: expertCount do: [ :e |
		(logits at: e) > best ifTrue: [ best := logits at: e. bestIndex := e ] ].
	^ bestIndex
]

{ #category : 'math' }
GcMoeRouter >> transposeTimesVector: anExpertVector [
	"W^T . y : a hiddenSize-vector accumulated over experts, so M.x = W^T (W x) is computed WITHOUT ever materializing W^T W (d x d). Cost E*d."
	| acc |
	acc := Array new: hiddenSize withAll: 0.0.
	1 to: expertCount do: [ :e |
		| ye row |
		ye := anExpertVector at: e.
		row := weightMatrix at: e.
		1 to: hiddenSize do: [ :i | acc at: i put: (acc at: i) + (ye * (row at: i)) ] ].
	^ acc
]

{ #category : 'accessing' }
GcMoeRouter >> weightMatrix [
	^ weightMatrix
]
