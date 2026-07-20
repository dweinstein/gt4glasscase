"
Undertrained-token analysis (glitch-token family, DW-19). Given a 2-D embedding tensor (vocab x hidden), a control band of contiguous rows, and a candidate id set, it fetches ONE ranged read per band plus one per candidate row (I5: never the whole matrix), decodes them (GcDtypeDecoder, f32/bf16), and measures each candidate's embedding L2 norm and its Euclidean distance to the control-band CENTROID (the per-column mean of the control rows -- an APPROXIMATION of the true full-vocab embedding centroid, labelled as such). Undertrained tokens sit near the centroid with small norm; they reveal tokenizer-corpus vs model-corpus mismatch and are natural Phase-5 trigger candidates. Provenance-honest: which rows were sampled (controlBandStart/Size), the centroid basis, and n-of-N are all first-class. Views (norm-vs-id scatter, ranked list) read cached state only; the bounded fetch happens in an example or an explicit <gtAction>. Build with the class-side detector embeddingRef:unembeddingRef:vocab:controlBandStart:controlBandSize:candidateIds:.
"
Class {
	#name : 'GcUndertrainedScan',
	#superclass : 'Object',
	#instVars : [
		'embeddingRef',
		'unembeddingRef',
		'innerSize',
		'tied',
		'controlBandStart',
		'controlBandSize',
		'controlIds',
		'controlNorms',
		'controlDistances',
		'centroid',
		'candidates',
		'candidateGroup'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'detecting' }
GcUndertrainedScan class >> embeddingRef: aRef unembeddingRef: anLmHeadRefOrNil vocab: idToText controlBandStart: aStart controlBandSize: aCount candidateIds: candidateIds [
	"THE detector. aRef is a 2-D vocab x hidden embedding tensor; anLmHeadRefOrNil is the untied output projection (nil = tied); idToText maps token id -> string. Fetches one control band + one row per candidate (I5), scores each, returns the ranked scan."
	^ self new
		computeFor: aRef
		unembedding: anLmHeadRefOrNil
		vocab: idToText
		controlBandStart: aStart
		controlBandSize: aCount
		candidateIds: candidateIds
]

{ #category : 'handoff' }
GcUndertrainedScan >> asTriggerCandidates [
	"Map every scored candidate to a Phase-5 GcTrigger (token form, prefix position), most-suspicious first."
	^ candidates collect: [ :ut | ut asTrigger ]
]

{ #category : 'detecting' }
GcUndertrainedScan >> buildCandidate: id vocab: idToText [
	| rowVals eNorm dist uNorm nScore cScore s vt |
	rowVals := (embeddingRef rowSliceAt: id) values.
	eNorm := self l2Norm: rowVals.
	dist := self distanceFrom: rowVals to: centroid.
	uNorm := tied
		ifTrue: [ eNorm ]
		ifFalse: [ unembeddingRef isNil
			ifTrue: [ nil ]
			ifFalse: [ self l2Norm: (unembeddingRef rowSliceAt: id) values ] ].
	nScore := self percentileExceeding: eNorm in: controlNorms.
	cScore := self percentileExceeding: dist in: controlDistances.
	s := (nScore + cScore) / 2.
	vt := GcVocabToken id: id text: (idToText at: id ifAbsent: [ '<id ', id printString, '>' ]).
	^ GcUndertrainedToken
		vocabToken: vt
		embeddingNorm: eNorm
		unembeddingNorm: uNorm
		tied: tied
		centroidDistance: dist
		normScore: nScore
		centroidScore: cScore
		score: s
]

{ #category : 'accessing' }
GcUndertrainedScan >> candidateGroup [
	"The lineage-stamped GcTokenGroup of the scored candidates' underlying vocab tokens."
	^ candidateGroup
]

{ #category : 'accessing' }
GcUndertrainedScan >> candidates [
	^ candidates
]

{ #category : 'accessing' }
GcUndertrainedScan >> centroid [
	^ centroid
]

{ #category : 'provenance' }
GcUndertrainedScan >> centroidBasisLabel [
	^ 'centroid = per-column mean of the ', controlBandSize printString, '-row control band (approx. of the true embedding centroid)'
]

{ #category : 'private' }
GcUndertrainedScan >> centroidOf: rows dimension: inner [
	| acc n |
	n := rows size.
	n = 0 ifTrue: [ ^ Array new: inner withAll: 0.0 ].
	acc := Array new: inner withAll: 0.0.
	rows do: [ :row |
		1 to: inner do: [ :j | acc at: j put: (acc at: j) + (row at: j) ] ].
	^ acc collect: [ :total | total / n ]
]

{ #category : 'detecting' }
GcUndertrainedScan >> computeFor: aRef unembedding: anLmHeadRefOrNil vocab: idToText controlBandStart: aStart controlBandSize: aCount candidateIds: candidateIds [
	| inner bandSlice bandVals rows |
	embeddingRef := aRef.
	unembeddingRef := anLmHeadRefOrNil.
	tied := anLmHeadRefOrNil isNil.
	controlBandStart := aStart.
	controlBandSize := aCount.
	inner := aRef innerSize.
	innerSize := inner.
	bandSlice := aRef rowBandSliceFrom: aStart count: aCount.
	bandVals := bandSlice values.
	rows := (0 to: aCount - 1) collect: [ :r |
		bandVals copyFrom: r * inner + 1 to: (r + 1) * inner ].
	centroid := self centroidOf: rows dimension: inner.
	controlIds := (aStart to: aStart + aCount - 1) asArray.
	controlNorms := rows collect: [ :row | self l2Norm: row ].
	controlDistances := rows collect: [ :row | self distanceFrom: row to: centroid ].
	candidates := candidateIds asArray collect: [ :id | self buildCandidate: id vocab: idToText ].
	candidates := (candidates asSortedCollection: [ :a :b |
		a score > b score or: [ a score = b score and: [ a embeddingNorm < b embeddingNorm ] ] ]) asArray.
	candidateGroup := GcTokenGroup new
		withItems: (candidates collect: [ :ut | ut vocabToken ])
		derivedBy: #undertrainedScan
		parameters: (Dictionary new
			at: #tensor put: aRef name;
			at: #controlBandStart put: aStart;
			at: #controlBandSize put: aCount;
			yourself).
	^ self
]

{ #category : 'accessing' }
GcUndertrainedScan >> controlBandSize [
	^ controlBandSize
]

{ #category : 'accessing' }
GcUndertrainedScan >> controlBandStart [
	^ controlBandStart
]

{ #category : 'accessing' }
GcUndertrainedScan >> controlDistances [
	^ controlDistances
]

{ #category : 'accessing' }
GcUndertrainedScan >> controlIds [
	^ controlIds
]

{ #category : 'accessing' }
GcUndertrainedScan >> controlNorms [
	^ controlNorms
]

{ #category : 'private' }
GcUndertrainedScan >> distanceFrom: aVector to: bVector [
	| sum |
	sum := 0.0.
	1 to: aVector size do: [ :i | | d |
		d := (aVector at: i) - (bVector at: i).
		sum := sum + (d * d) ].
	^ sum sqrt
]

{ #category : 'accessing' }
GcUndertrainedScan >> embeddingRef [
	^ embeddingRef
]

{ #category : 'gt views' }
GcUndertrainedScan >> gtNormScatterFor: aView [
	<gtView>
	"Norm vs token id: the control band as small grey dots, undertrained candidates coloured by suspicion score. Undertrained tokens fall off the main norm band toward zero. X = token id for now; the merge-rank X-axis arrives with DW-18."
	candidates ifNil: [ ^ aView empty ].
	^ aView explicit
		title: 'Norm vs token id';
		priority: 2;
		stencil: [ self scatterElement ]
]

{ #category : 'gt views' }
GcUndertrainedScan >> gtProvenanceFor: aView [
	<gtView>
	"How was this scan made? Honest provenance: which rows were sampled, band size, centroid basis, ranged reads."
	^ aView columnedList
		title: 'Provenance';
		priority: 4;
		items: [ self provenanceFacets ];
		column: 'Facet' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ]
]

{ #category : 'gt views' }
GcUndertrainedScan >> gtRankedCandidatesFor: aView [
	<gtView>
	"Which vocabulary tokens look undertrained -- small embedding norm, near the centroid? Ranked by suspicion score."
	candidates ifNil: [ ^ aView empty ].
	^ aView columnedList
		title: 'Undertrained candidates';
		priority: 1;
		items: [ candidates ];
		column: 'Token' text: [ :ut | ut text printString ];
		column: 'Id' text: [ :ut | ut tokenId printString ];
		column: 'Bytes' text: [ :ut | ut hexBytes ];
		column: 'Norm' text: [ :ut | ut embeddingNorm asFloat printShowingDecimalPlaces: 4 ];
		column: 'Centroid dist' text: [ :ut | ut centroidDistance asFloat printShowingDecimalPlaces: 4 ];
		column: 'Score' text: [ :ut | ut score asFloat printShowingDecimalPlaces: 3 ];
		send: [ :ut | ut ]
]

{ #category : 'private' }
GcUndertrainedScan >> l2Norm: aVector [
	^ (aVector inject: 0.0 into: [ :acc :v | acc + (v * v) ]) sqrt
]

{ #category : 'private' }
GcUndertrainedScan >> percentileExceeding: aValue in: aCollection [
	"Fraction of the control population strictly greater than aValue -- a rank-normalized [0,1] score (1 = smaller / nearer than everything in the band)."
	aCollection isEmpty ifTrue: [ ^ 0 ].
	^ (aCollection count: [ :each | each > aValue ]) / aCollection size
]

{ #category : 'printing' }
GcUndertrainedScan >> printOn: aStream [
	aStream nextPutAll: 'undertrained scan ('; print: self size; nextPutAll: ' candidates, '; nextPutAll: (tied == true ifTrue: [ 'tied' ] ifFalse: [ 'untied' ]); nextPut: $)
]

{ #category : 'provenance' }
GcUndertrainedScan >> provenanceFacets [
	^ {
		'Embedding tensor' -> embeddingRef name.
		'Shape' -> embeddingRef shape printString.
		'Dtype' -> embeddingRef dtype.
		'Output tied?' -> tied.
		'Control band start' -> controlBandStart.
		'Control band size' -> controlBandSize.
		'Vocab rows total' -> embeddingRef dimensions first.
		'Centroid basis' -> self centroidBasisLabel.
		'Candidates scored' -> self size.
		'Ranged reads' -> (1 + self size) }
]

{ #category : 'provenance' }
GcUndertrainedScan >> provenanceLabel [
	^ 'control rows ', controlBandStart printString, '-', (controlBandStart + controlBandSize - 1) printString,
		' (', controlBandSize printString, ' of ', embeddingRef dimensions first printString, ' vocab); ',
		self size printString, ' candidates scored'
]

{ #category : 'gt views' }
GcUndertrainedScan >> scatterChart [
	"The configured norm-vs-id scatter chart: control band grey, candidates coloured by score. Reads cached state only."
	| data |
	data := GtPlotterDataGroup new values: self scatterPoints.
	^ GtPlotterScatterChart new
		with: data;
		valueX: [ :p | p at: #id ];
		scaleX: GtPlotterLinearScale new;
		titleX: 'Token id';
		ticksX: 8;
		valueY: [ :p | p at: #norm ];
		scaleY: GtPlotterLinearScale new;
		titleY: 'Embedding L2 norm';
		ticksY: 8;
		dotElement: [ :ctx | | p isCand |
			p := ctx originalValue.
			isCand := (p at: #kind) = #candidate.
			BlElement new
				geometry: BlCircleGeometry new;
				size: (isCand ifTrue: [ 12 ] ifFalse: [ 5 ]) asPoint;
				background: (isCand
					ifTrue: [ self scoreColor: (p at: #score) ]
					ifFalse: [ Color gray alpha: 0.35 ]);
				aptitude: (BrGlamorousWithExplicitTooltipAptitude text: (p at: #label)) ];
		yourself
]

{ #category : 'gt views' }
GcUndertrainedScan >> scatterElement [
	"The rendered norm-vs-id scatter as a BlElement."
	^ self scatterChart create
]

{ #category : 'private' }
GcUndertrainedScan >> scatterPoints [
	"Control rows (grey) plus scored candidates (colored) as plottable points for the norm-vs-id scatter."
	| points |
	points := OrderedCollection new.
	controlIds withIndexDo: [ :id :i |
		points add: (Dictionary new
			at: #id put: id;
			at: #norm put: (controlNorms at: i) asFloat;
			at: #kind put: #control;
			at: #score put: 0;
			at: #label put: 'control row ', id printString;
			yourself) ].
	candidates do: [ :ut |
		points add: (Dictionary new
			at: #id put: ut tokenId;
			at: #norm put: ut embeddingNorm asFloat;
			at: #kind put: #candidate;
			at: #score put: ut score;
			at: #label put: ut text printString, ' score=', (ut score asFloat printShowingDecimalPlaces: 3);
			yourself) ].
	^ points asArray
]

{ #category : 'private' }
GcUndertrainedScan >> scoreColor: aScore [
	| s |
	s := (aScore asFloat max: 0.0) min: 1.0.
	^ Color r: 1.0 g: 0.75 * (1.0 - s) b: 0.1
]

{ #category : 'accessing' }
GcUndertrainedScan >> size [
	^ candidates ifNil: [ 0 ] ifNotNil: [ candidates size ]
]

{ #category : 'accessing' }
GcUndertrainedScan >> tied [
	^ tied
]

{ #category : 'handoff' }
GcUndertrainedScan >> topCandidates: n [
	"Phase-5 handoff: the n most-suspicious tokens as a lineage-stamped GcTokenGroup of vocab tokens, consumable as trigger candidates."
	| top |
	top := (candidates first: (n min: candidates size)) collect: [ :ut | ut vocabToken ].
	^ candidateGroup
		withItems: top
		derivedBy: #topCandidates
		parameters: (Dictionary new at: #n put: n; yourself)
]
