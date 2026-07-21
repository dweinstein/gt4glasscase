"
Stage C top object: a set of GcConceptAxes plus a set of PLACED words, embedded in ONE GcEmbeddingModel built over the union of every axis concept's words and every placed word (each tokenized + mean-pooled ONCE, so all directions and words share one geometry). Answers the LRH questions interactively: gtPlaneFor: plots every placed word on a plane whose two axes are two chosen concept DIRECTIONS (default the first two, e.g. gender x sentiment) -- words sort by how much of each concept they carry; gtAnglesFor: is the N x N inter-axis ANGLE matrix (degrees) so you can see which concept directions are independent (~90) vs entangled (<~60); gtAxesFor: lists the axes, each drilling into its most-positive/most-negative placed words. Class-side defaultGpt2 seeds gender/sentiment/size/royalty axes and ~12 test words on the LOCAL gpt2 (no network). Mirrors GcConceptSpace (colored members, warmUp, cached geometry, scatter idiom) and GcEmbeddingComparison (word-spec build, square explicit plot).
"
Class {
	#name : 'GcConceptAxisSpace',
	#superclass : 'Object',
	#instVars : [
		'name',
		'axes',
		'placedWords',
		'model',
		'tokenizer',
		'wordVectorsByWordCache',
		'placedWordVectorsCache',
		'directionsCache',
		'angleMatrixCache',
		'allWordsCache'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptAxisSpace class >> axes: anAxes words: placedWords model: aModel wordSpecs: aSpecs [
	"Build from pre-tokenized union word specs (each { word. tokenIds. pieces }). Used for synthetic / no-tokenizer models (hermetic tests)."
	^ self new setAxes: anAxes words: placedWords tokenizer: nil model: aModel wordSpecs: aSpecs
]

{ #category : 'instance creation' }
GcConceptAxisSpace class >> axes: anAxes words: placedWords tokenizer: aTokenizer model: aModel [
	"Build a space by tokenizing the union of every axis concept word and every placed word ONCE, then mean-pooling in aModel."
	| unionWords specs |
	unionWords := self unionWordsOf: anAxes placed: placedWords.
	specs := unionWords collect: [ :w |
		| ids |
		ids := aTokenizer encode: w.
		{ w. ids. (ids collect: [ :id | aTokenizer decode: { id } ]) } ].
	^ self new setAxes: anAxes words: placedWords tokenizer: aTokenizer model: aModel wordSpecs: specs
]

{ #category : 'defaults' }
GcConceptAxisSpace class >> colorAt: anIndex [
	"Reuse the concept-space categorical palette; axis i gets colorAt: i."
	| palette |
	palette := GcConceptSpace defaultColors.
	^ palette at: ((anIndex - 1) \\ palette size) + 1
]

{ #category : 'defaults' }
GcConceptAxisSpace class >> defaultAxes [
	"Four recognizable contrastive concept axes over leading-space GPT-2 words; mean-pooling handles multi-token words."
	^ {
		GcConceptAxis
			name: 'gender'
			positive: (GcConcept name: 'female' words: #(' woman' ' queen' ' girl' ' mother'))
			negative: (GcConcept name: 'male' words: #(' man' ' king' ' boy' ' father')).
		GcConceptAxis
			name: 'sentiment'
			positive: (GcConcept name: 'positive' words: #(' good' ' happy' ' love' ' great'))
			negative: (GcConcept name: 'negative' words: #(' bad' ' sad' ' hate' ' awful')).
		GcConceptAxis
			name: 'size'
			positive: (GcConcept name: 'big' words: #(' huge' ' giant' ' large' ' massive'))
			negative: (GcConcept name: 'small' words: #(' tiny' ' little' ' small' ' miniature')).
		GcConceptAxis
			name: 'royalty'
			positive: (GcConcept name: 'royal' words: #(' king' ' queen' ' prince' ' duke'))
			negative: (GcConcept name: 'common' words: #(' peasant' ' servant' ' worker' ' commoner')) }
]

{ #category : 'defaults' }
GcConceptAxisSpace class >> defaultGpt2 [
	"The default gender/sentiment/size/royalty axes and a dozen placed words embedded in the LOCAL gpt2 (f32, no network)."
	^ self axes: self defaultAxes words: self defaultPlacedWords tokenizer: GcTokenizer gpt2 model: GcEmbeddingModel localGpt2
]

{ #category : 'defaults' }
GcConceptAxisSpace class >> defaultPlacedWords [
	"A dozen recognizable test words to place on the concept plane (leading-space GPT-2 tokens)."
	^ #(' king' ' queen' ' man' ' woman' ' dog' ' giant' ' ant' ' happy' ' sad' ' love' ' France' ' gold')
]

{ #category : 'building' }
GcConceptAxisSpace class >> unionWordsOf: anAxes placed: placedWords [
	"The de-duplicated union of every axis concept's positive+negative words and every placed word, in first-seen order."
	| seen ordered add |
	seen := Set new.
	ordered := OrderedCollection new.
	add := [ :w | (seen includes: w) ifFalse: [ seen add: w. ordered add: w ] ].
	anAxes do: [ :axis |
		axis positiveWords do: add.
		axis negativeWords do: add ].
	placedWords do: add.
	^ ordered asArray
]

{ #category : 'geometry' }
GcConceptAxisSpace >> angleBetween: anAxis and: anotherAxis [
	^ anAxis angleTo: anotherAxis in: model
]

{ #category : 'geometry' }
GcConceptAxisSpace >> angleMatrix [
	"The N x N inter-axis angle matrix (degrees), rows/cols in axis order; diagonal = 0."
	^ angleMatrixCache ifNil: [
		angleMatrixCache := axes collect: [ :a |
			axes collect: [ :b | a angleTo: b in: model ] ] ]
]

{ #category : 'rendering' }
GcConceptAxisSpace >> anglesCaption [
	^ 'Inter-axis angle (degrees): ~90 = independent concept directions; small (or ~180) = entangled. Diagonal = 0. Cells click to the axis pair.'
]

{ #category : 'rendering' }
GcConceptAxisSpace >> anglesCellElement: aDegrees pair: aPair width: aWidth height: aHeight [
	| cell label e |
	e := (aDegrees * Float pi / 180.0) cos abs.
	cell := BlElement new
		layout: BlFrameLayout new;
		constraintsDo: [ :c | c horizontal exact: aWidth. c vertical exact: aHeight ];
		background: (self colorForAngle: aDegrees);
		border: (BlBorder paint: Color white width: 1);
		yourself.
	label := BlTextElement new
		text: ((aDegrees printShowingDecimalPlaces: 1) asRopedText
			foreground: (e > 0.55 ifTrue: [ Color white ] ifFalse: [ Color black ]));
		constraintsDo: [ :c | c frame horizontal alignCenter. c frame vertical alignCenter ];
		yourself.
	cell addChild: label.
	cell addEventHandlerOn: BlClickEvent do: [ :evt | cell phlow spawnObject: aPair ].
	^ cell
]

{ #category : 'rendering' }
GcConceptAxisSpace >> anglesElement [
	"An N x N inter-axis angle heatmap: cells colored white (independent, ~90 deg) -> red (entangled, ~0/180 deg), labeled by axis name in axis color. Each cell clicks to its GcConceptAxisPair."
	| n cellW cellH labelW am container header |
	n := axes size.
	cellW := 66. cellH := 30. labelW := 96.
	am := self angleMatrix.
	container := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		yourself.
	container addChild: (BlTextElement new text: (self anglesCaption asRopedText foreground: Color gray darker)).
	header := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		yourself.
	header addChild: (self anglesLabelElement: '' color: Color transparent width: labelW).
	axes do: [ :ax | header addChild: (self anglesLabelElement: ax name color: ax color width: cellW) ].
	container addChild: header.
	1 to: n do: [ :i |
		| row rowAxis |
		rowAxis := axes at: i.
		row := BlElement new
			layout: BlLinearLayout horizontal;
			constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
			yourself.
		row addChild: (self anglesLabelElement: rowAxis name color: rowAxis color width: labelW).
		1 to: n do: [ :j |
			| pair |
			pair := GcConceptAxisPair first: rowAxis second: (axes at: j) in: self.
			row addChild: (self anglesCellElement: ((am at: i) at: j) pair: pair width: cellW height: cellH) ].
		container addChild: row ].
	^ container
]

{ #category : 'rendering' }
GcConceptAxisSpace >> anglesLabelElement: aString color: aColor width: aWidth [
	^ BlTextElement new
		text: (aString asRopedText foreground: aColor);
		padding: (BlInsets all: 2);
		constraintsDo: [ :c | c horizontal exact: aWidth. c vertical fitContent ];
		yourself
]

{ #category : 'accessing' }
GcConceptAxisSpace >> axes [
	^ axes
]

{ #category : 'rendering' }
GcConceptAxisSpace >> colorForAngle: aDegrees [
	"Entanglement e = |cos(angle)|: 0 at 90 deg (independent) -> white; 1 at 0/180 deg (aligned/anti-aligned) -> deep red."
	| e |
	e := (aDegrees * Float pi / 180.0) cos abs.
	e := (e max: 0.0) min: 1.0.
	^ Color r: 1.0 - (e * 0.1) g: 1.0 - (e * 0.62) b: 1.0 - (e * 0.62)
]

{ #category : 'geometry' }
GcConceptAxisSpace >> directionFor: anAxis [
	^ self directions at: anAxis
]

{ #category : 'geometry' }
GcConceptAxisSpace >> directions [
	"axis -> its unit direction Float64Array within this space's model."
	^ directionsCache ifNil: [
		| d |
		d := IdentityDictionary new.
		axes do: [ :ax | d at: ax put: (ax directionIn: model) ].
		directionsCache := d ]
]

{ #category : 'gt views' }
GcConceptAxisSpace >> gtAnglesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Angles';
		priority: 12;
		stencil: [ self anglesElement ]
]

{ #category : 'gt views' }
GcConceptAxisSpace >> gtAxesFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Axes';
		priority: 20;
		items: [ axes ];
		column: 'Axis' text: [ :ax | ax name ];
		column: 'Negative (-)' text: [ :ax | ax negativeLabel ];
		column: 'Positive (+)' text: [ :ax | ax positiveLabel ];
		send: [ :ax | ax ]
]

{ #category : 'gt views' }
GcConceptAxisSpace >> gtPlaneFor: aView [
	<gtView>
	^ aView explicit
		title: 'Plane';
		priority: 10;
		stencil: [ self planeElement ]
]

{ #category : 'gt views' }
GcConceptAxisSpace >> gtWordsFor: aView [
	<gtView>
	| list |
	list := aView columnedList
		title: 'Words';
		priority: 16;
		items: [ self placedWordRows ];
		column: 'Word' text: [ :row | row first trimBoth ];
		send: [ :row | row third ].
	axes doWithIndex: [ :ax :i |
		list column: ax name text: [ :row | (row second at: i) printShowingDecimalPlaces: 3 ] ].
	^ list
]

{ #category : 'accessing' }
GcConceptAxisSpace >> model [
	^ model
]

{ #category : 'accessing' }
GcConceptAxisSpace >> name [
	^ name
]

{ #category : 'accessing' }
GcConceptAxisSpace >> name: aString [
	name := aString
]

{ #category : 'geometry' }
GcConceptAxisSpace >> placedProjectionsForAxis: anAxis [
	"Each placed word as { word. projection. wordVector } on anAxis, sorted most-positive first."
	| dir rows |
	dir := self directionFor: anAxis.
	rows := placedWords collect: [ :w |
		| wv |
		wv := self wordVectorForWord: w.
		{ w. (model dotArr: wv vector with: dir). wv } ].
	^ (rows asSortedCollection: [ :x :y | (x at: 2) >= (y at: 2) ]) asArray
]

{ #category : 'geometry' }
GcConceptAxisSpace >> placedWordRows [
	"Each placed word as { word. {projection per axis}. wordVector } for the tabular Words view."
	| dirs |
	dirs := axes collect: [ :ax | self directionFor: ax ].
	^ placedWords collect: [ :w |
		| wv |
		wv := self wordVectorForWord: w.
		{ w. (dirs collect: [ :d | model dotArr: wv vector with: d ]). wv } ]
]

{ #category : 'geometry' }
GcConceptAxisSpace >> placedWordVectors [
	"The GcWordVectors of the placed words, in placement order."
	^ placedWordVectorsCache ifNil: [
		placedWordVectorsCache := placedWords collect: [ :w | self wordVectorForWord: w ] ]
]

{ #category : 'accessing' }
GcConceptAxisSpace >> placedWords [
	^ placedWords
]

{ #category : 'rendering' }
GcConceptAxisSpace >> planeCaption [
	^ 'Concept plane: ' , (placedWords size) printString , ' words placed on x = ' , (axes at: 1) name , ' (' , (axes at: 1) negativeLabel , ' -> ' , (axes at: 1) positiveLabel , '), y = ' , (axes at: 2) name , ' (' , (axes at: 2) negativeLabel , ' -> ' , (axes at: 2) positiveLabel , ') directions in ' , (model label ifNil: [ '?' ])
]

{ #category : 'rendering' }
GcConceptAxisSpace >> planeElement [
	| caption |
	axes size < 2 ifTrue: [ ^ BlTextElement new text: 'Need at least 2 axes for a plane' asRopedText ].
	caption := BlTextElement new text: (self planeCaption asRopedText foreground: Color gray darker).
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		addChildren: { caption. (self planeElementForAxis1: (axes at: 1) axis2: (axes at: 2)) };
		yourself
]

{ #category : 'rendering' }
GcConceptAxisSpace >> planeElementForAxis1: axis1 axis2: axis2 [
	"A labeled scatter of every placed word at (proj on axis1, proj on axis2). Origin (0,0) is shown as a crosshair; the two axis directions are labeled negative -> positive. Each dot clicks to its GcWordVector."
	| pts w h pad xs ys minX maxX minY maxY spanX spanY xOf yOf container x0 y0 |
	pts := self planePointsForAxis1: axis1 axis2: axis2.
	w := 580. h := 470. pad := 60.
	container := BlElement new
		size: w @ h;
		background: Color white;
		border: (BlBorder paint: (Color gray alpha: 0.4) width: 1);
		yourself.
	pts isEmpty ifTrue: [ ^ container ].
	xs := pts collect: [ :p | p at: 2 ].
	ys := pts collect: [ :p | p at: 3 ].
	minX := (xs copyWith: 0.0) min. maxX := (xs copyWith: 0.0) max.
	minY := (ys copyWith: 0.0) min. maxY := (ys copyWith: 0.0) max.
	spanX := maxX - minX. spanX = 0 ifTrue: [ spanX := 1.0 ].
	spanY := maxY - minY. spanY = 0 ifTrue: [ spanY := 1.0 ].
	xOf := [ :vx | pad + ((vx - minX) / spanX * (w - (2 * pad))) ].
	yOf := [ :vy | h - pad - ((vy - minY) / spanY * (h - (2 * pad))) ].
	x0 := xOf value: 0.0.
	y0 := yOf value: 0.0.
	container addChild: (self planeLineFrom: x0 @ pad to: x0 @ (h - pad) extent: w @ h color: (Color gray alpha: 0.35) width: 1).
	container addChild: (self planeLineFrom: pad @ y0 to: (w - pad) @ y0 extent: w @ h color: (Color gray alpha: 0.35) width: 1).
	pts do: [ :p |
		| word cx cy wv dotEl lblEl |
		word := p at: 1.
		cx := xOf value: (p at: 2).
		cy := yOf value: (p at: 3).
		wv := p at: 4.
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 10 @ 10;
			background: (Color r: 0.15 g: 0.4 b: 0.85);
			position: (cx - 5) @ (cy - 5);
			yourself.
		dotEl addEventHandlerOn: BlClickEvent do: [ :e | dotEl phlow spawnObject: wv ].
		lblEl := BlTextElement new
			text: (word trimBoth asRopedText foreground: (Color black alpha: 0.8));
			position: (cx + 6) @ (cy - 8);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ].
	container addChild: (BlTextElement new
		text: ('<-- ' , axis1 negativeLabel , '      x: ' , axis1 name , '      ' , axis1 positiveLabel , ' -->') asRopedText;
		position: pad @ (h - 26);
		yourself).
	container addChild: (BlTextElement new
		text: ('^ ' , axis2 positiveLabel , '   /   ' , axis2 negativeLabel , ' v   (y: ' , axis2 name , ')') asRopedText;
		position: 8 @ 8;
		yourself).
	^ container
]

{ #category : 'rendering' }
GcConceptAxisSpace >> planeLineFrom: p1 to: p2 extent: anExtent color: aColor width: aWidth [
	"A thin line element spanning the whole plot so its local coordinate space matches the plot's (same idiom as GcEmbeddingModel>>lineFrom:to:extent:)."
	^ BlElement new
		size: anExtent;
		geometry: (BlLineGeometry from: p1 to: p2);
		outskirts: BlOutskirts outside;
		border: (BlBorder paint: aColor width: aWidth);
		yourself
]

{ #category : 'geometry' }
GcConceptAxisSpace >> planePointsForAxis1: axis1 axis2: axis2 [
	"Each placed word as { word. projOnAxis1. projOnAxis2. wordVector } -- its coordinates on the concept plane."
	| d1 d2 |
	d1 := self directionFor: axis1.
	d2 := self directionFor: axis2.
	^ placedWords collect: [ :w |
		| wv |
		wv := self wordVectorForWord: w.
		{ w. (model dotArr: wv vector with: d1). (model dotArr: wv vector with: d2). wv } ]
]

{ #category : 'printing' }
GcConceptAxisSpace >> printOn: aStream [
	aStream nextPutAll: self class name.
	axes ifNil: [ ^ self ].
	aStream nextPutAll: ' ('; print: axes size; nextPutAll: ' axes, '; print: (placedWords ifNil: [ #() ]) size; nextPutAll: ' words)'
]

{ #category : 'initialization' }
GcConceptAxisSpace >> setAxes: anAxes words: aPlacedWords tokenizer: aTokenizer model: aModel wordSpecs: aSpecs [
	axes := anAxes asArray.
	placedWords := aPlacedWords asArray.
	tokenizer := aTokenizer.
	model := aModel.
	axes doWithIndex: [ :ax :i | ax space: self. ax color: (self class colorAt: i) ].
	model wordSpecs: aSpecs; seed: 1.
	self warmUp
]

{ #category : 'accessing' }
GcConceptAxisSpace >> tokenizer [
	^ tokenizer
]

{ #category : 'initialization' }
GcConceptAxisSpace >> warmUp [
	"Eagerly compute word vectors, per-word index, axis directions and the angle matrix so gtViews read caches only (no network in views)."
	model wordVectors.
	self wordVectorsByWord.
	self directions.
	self angleMatrix
]

{ #category : 'geometry' }
GcConceptAxisSpace >> wordVectorForWord: aWord [
	^ self wordVectorsByWord at: aWord ifAbsent: [ nil ]
]

{ #category : 'geometry' }
GcConceptAxisSpace >> wordVectorsByWord [
	"word -> its mean-pooled GcWordVector in this space's model."
	^ wordVectorsByWordCache ifNil: [
		| d |
		d := Dictionary new.
		model words doWithIndex: [ :w :i | d at: w put: (model wordVectorAt: i) ].
		wordVectorsByWordCache := d ]
]
