"
The ordered BPE merge list of a tokenizer (DW-18): a first-class wrapper over the rank-ordered GcMergeRules, built from vocab+merges metadata only (no weights, no corpus). It answers corpus-fingerprint questions: rankForToken: (the rank at which a vocab piece was first formed, nil for base bytes), rankOfPair:/ruleAt:, categoryCompositionOverRank (produced-category composition as rank grows -- the fingerprint chart data), and suspectedManualMerges (a HEURISTIC, see #manualMergeReasonFor:, flagging merges that look hand-inserted rather than frequency-learned). Because merges are ordered by training frequency, the early ranks proxy what the corpus over-represents (lots of early CJK/other-non-ASCII => multilingual; lots of early punctuation/symbol => code-heavy). This is a PROXY, not the data-mixture LP result -- that solve is delegated to the Python oracle (GcMixtureInference, gc-harness Tier-2). suspectedManualMerges returns another GcMergeList so results stay moldable.
"
Class {
	#name : 'GcMergeList',
	#superclass : 'Object',
	#instVars : [
		'tokenizer',
		'rules',
		'rankIndex',
		'pairIndex',
		'manualMergeCutoff'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcMergeList class >> fromMergesArray: anArray [
	"Build from a tokenizer.json model.merges array: each entry is 'A B' or #(A B); array index = 0-based rank."
	| rules |
	rules := OrderedCollection new.
	anArray doWithIndex: [ :entry :i |
		| parts |
		parts := self partsFromMergeEntry: entry.
		parts ifNotNil: [
			rules add: (GcMergeRule left: parts first right: parts second rank: rules size) ] ].
	^ self rules: rules
]

{ #category : 'instance creation' }
GcMergeList class >> fromMergesText: aString [
	"Build from a legacy gpt2-style merges.txt: one 'A B' per line; a leading '#version' header line is skipped; line order = 0-based rank."
	| rules |
	rules := OrderedCollection new.
	aString lines doWithIndex: [ :line :i |
		(i = 1 and: [ line beginsWith: '#version' ])
			ifFalse: [
				| parts |
				parts := self partsFromMergeEntry: line.
				parts ifNotNil: [
					rules add: (GcMergeRule left: parts first right: parts second rank: rules size) ] ] ].
	^ self rules: rules
]

{ #category : 'instance creation' }
GcMergeList class >> partsFromMergeEntry: entry [
	"Return a 2-element array {left. right} from a merge entry, or nil if malformed. Entry is an 'A B' string or a #(A B) array. Pieces never contain literal ASCII whitespace (byte-level BPE encodes space as U+0120), so a generic whitespace split is safe."
	entry isString ifTrue: [
		| parts |
		parts := entry substrings.
		^ parts size = 2 ifTrue: [ { parts first. parts second } ] ifFalse: [ nil ] ].
	(entry isCollection and: [ entry size = 2 ]) ifTrue: [
		^ { entry first. entry second } ].
	^ nil
]

{ #category : 'instance creation' }
GcMergeList class >> rules: aCollection [
	^ self new setRules: aCollection
]

{ #category : 'fingerprint' }
GcMergeList >> categoryColors [
	"Series colour per produced category (keys are category symbols asString)."
	^ Dictionary new
		at: 'whitespace' put: Color gray;
		at: 'digit' put: Color orange;
		at: 'asciiLetter' put: Color blue;
		at: 'punctuation' put: Color green;
		at: 'cjk' put: Color red;
		at: 'otherNonAscii' put: Color purple;
		yourself
]

{ #category : 'fingerprint' }
GcMergeList >> categoryCompositionOverRank [
	"One record per checkpoint k: #rank -> k, #cumulative -> (category -> count over the first k merges). The data behind the corpus-fingerprint chart; counts are exact at each checkpoint."
	| checkpoints running result idx cats |
	cats := GcMergeRule categories.
	running := Dictionary new.
	cats do: [ :c | running at: c put: 0 ].
	checkpoints := self compositionCheckpoints asSortedCollection asArray.
	result := OrderedCollection new.
	idx := 1.
	self rules doWithIndex: [ :r :i |
		running at: r producedCategory put: (running at: r producedCategory ifAbsent: [ 0 ]) + 1.
		[ idx <= checkpoints size and: [ (checkpoints at: idx) = i ] ] whileTrue: [
			result add: (Dictionary new
				at: #rank put: i;
				at: #cumulative put: running copy;
				yourself).
			idx := idx + 1 ] ].
	^ result asArray
]

{ #category : 'fingerprint' }
GcMergeList >> categoryCounts [
	"Total count of merges per produced category over the whole list (exact)."
	| counts |
	counts := Dictionary new.
	GcMergeRule categories do: [ :c | counts at: c put: 0 ].
	self rules do: [ :r | | c |
		c := r producedCategory.
		counts at: c put: (counts at: c ifAbsent: [ 0 ]) + 1 ].
	^ counts
]

{ #category : 'fingerprint' }
GcMergeList >> compositionCheckpoints [
	"The rank counts k at which to snapshot cumulative composition. Small lists: every k (exact). Large lists: ~80 evenly spaced, always including the full size."
	| n step ks |
	n := self size.
	n <= 200 ifTrue: [ ^ (1 to: n) asArray ].
	step := (n // 80) max: 1.
	ks := (1 to: n by: step) asOrderedCollection.
	(ks includes: n) ifFalse: [ ks add: n ].
	^ ks asArray
]

{ #category : 'suspected merges' }
GcMergeList >> defaultLowRankCutoff [
	"Below this rank a merge is 'anomalously early'. ~1% of the list, at least 8, so it scales from a tiny synthetic list to a 50k learned tokenizer."
	^ (self size // 100) max: 8
]

{ #category : 'fingerprint' }
GcMergeList >> emptyFingerprintElement [
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 10);
		addChild: (BrLabel new aptitude: BrGlamorousLabelAptitude; text: 'no merges to fingerprint'; yourself);
		yourself
]

{ #category : 'fingerprint' }
GcMergeList >> fingerprintChartElement [
	"The composed corpus-fingerprint element: an honest subtitle over a multi-series line chart of cumulative per-category share vs merge rank. Y ticks are 2-decimal shares (never a whole-number formatter -- shares are sub-1.0); X ticks are whole-number ranks."
	| comp totals cats colors allData chartData chart chartElement subtitleLabel |
	comp := self categoryCompositionOverRank.
	comp isEmpty ifTrue: [ ^ self emptyFingerprintElement ].
	totals := self categoryCounts.
	cats := GcMergeRule categories select: [ :c | (totals at: c ifAbsent: [ 0 ]) > 0 ].
	colors := self categoryColors.
	allData := OrderedCollection new.
	comp do: [ :rec | | k cum |
		k := rec at: #rank.
		cum := rec at: #cumulative.
		cats do: [ :c |
			allData add: (Dictionary new
				at: #x put: k;
				at: #y put: ((cum at: c ifAbsent: [ 0 ]) / k) asFloat;
				at: #series put: c asString;
				yourself) ] ].
	chartData := (GtPlotterDataGroup new values: allData)
		groupedBy: [ :p | p at: #series ]
		labelled: [ :s | s ]
		colored: [ :s | colors at: s ifAbsent: [ Color black ] ].
	chart := GtPlotterLineChart new
		with: chartData;
		valueX: [ :p | p at: #x ];
		scaleX: GtPlotterLinearScale new;
		labelFormatX: [ :v | (v printShowingDecimalPlaces: 0) asRopedText foreground: Color darkGray ];
		titleX: 'Merge rank';
		ticksX: 8;
		valueY: [ :p | p at: #y ];
		scaleY: GtPlotterLinearScale new;
		labelFormatY: [ :v | (v printShowingDecimalPlaces: 2) asRopedText foreground: Color darkGray ];
		titleY: 'Cumulative share';
		ticksY: 6.
	chartElement := chart create.
	chartElement constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ].
	subtitleLabel := BrLabel new aptitude: BrGlamorousLabelAptitude; text: self fingerprintSubtitle; yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 5);
		addChild: subtitleLabel;
		addChild: chartElement;
		yourself
]

{ #category : 'fingerprint' }
GcMergeList >> fingerprintSubtitle [
	^ 'cumulative share of produced-token category vs merge rank over ' , self size printString , ' merges -- a PROXY for training-corpus composition (rank 0 = most frequent byte pair), NOT the data-mixture LP result'
]

{ #category : 'gt views' }
GcMergeList >> gtCorpusFingerprintFor: aView [
	<gtView>
	"What does the training corpus look like? Cumulative produced-token category composition across merge rank -- a proxy fingerprint (early ranks reveal what the corpus over-represents: lots of early CJK/other => multilingual; lots of early punctuation/symbol => code-heavy), NOT the data-mixture LP."
	self rules isEmpty ifTrue: [ ^ aView empty ].
	^ aView explicit
		title: 'Corpus fingerprint';
		priority: 1;
		stencil: [ self fingerprintChartElement ]
]

{ #category : 'gt views' }
GcMergeList >> gtMergesFor: aView [
	<gtView>
	"Every merge rule in rank order, byte-level for unprintables. Click a row to open the GcMergeRule."
	^ aView columnedList
		title: 'Merges';
		priority: 2;
		items: [ self rules ];
		column: 'Rank' text: [ :r | r rank printString ] width: 70;
		column: 'Pair' text: [ :r | r displayPair ];
		column: 'Merged' text: [ :r | r displayMerged ];
		column: 'Category' text: [ :r | r producedCategory asString ] width: 120;
		send: [ :r | r ]
]

{ #category : 'gt views' }
GcMergeList >> gtSearchMergesFor: aSearch [
	<gtSearch>
	^ aSearch list
		title: 'Merges';
		priority: 10;
		items: [ self rules ];
		itemName: [ :r | r rank printString , '  ' , r displayMerged ];
		filterBySubstring
]

{ #category : 'gt views' }
GcMergeList >> gtSuspectedManualMergesFor: aView [
	<gtView>
	"Which merges look hand-inserted rather than frequency-learned? A HEURISTIC (rank/position + structure; no corpus => no frequency evidence). Click a row to open the rule."
	^ aView columnedList
		title: 'Suspected manual merges';
		priority: 3;
		items: [ self suspectedManualMergeRules ];
		column: 'Rank' text: [ :r | r rank printString ] width: 70;
		column: 'Merged' text: [ :r | r displayMerged ] width: 160;
		column: 'Reason (heuristic)' text: [ :r | self manualMergeReasonFor: r ];
		send: [ :r | r ]
]

{ #category : 'accessing' }
GcMergeList >> items [
	"The merge rules, so the list is plug-compatible with collection-style views."
	^ self rules
]

{ #category : 'suspected merges' }
GcMergeList >> lowRankCutoff [
	^ manualMergeCutoff ifNil: [ self defaultLowRankCutoff ]
]

{ #category : 'accessing' }
GcMergeList >> manualMergeCutoff [
	^ manualMergeCutoff
]

{ #category : 'accessing' }
GcMergeList >> manualMergeCutoff: anIntegerOrNil [
	manualMergeCutoff := anIntegerOrNil
]

{ #category : 'suspected merges' }
GcMergeList >> manualMergeReasonFor: aRule [
	"HEURISTIC (not ground truth): flag a merge that looks hand-inserted rather than frequency-learned. Without a training corpus there is no frequency evidence, so the signal is POSITION plus STRUCTURE -- a merge at anomalously low rank (< lowRankCutoff) that is structurally unusual for that position: a whitespace run (the paper flags Gemma's space merges), a raw control-char merge, or a degenerate duplicate pair of NON-alphanumeric pieces (doubled letters/digits like 'll' or '00' are naturally frequent, so they are NOT flagged). Returns a reason string, or nil if not flagged. False positives are expected; this is a triage lens, not a verdict."
	aRule rank < self lowRankCutoff ifFalse: [ ^ nil ].
	aRule isWhitespaceRun ifTrue: [
		^ 'whitespace-run at low rank (' , aRule rank printString , ' < ' , self lowRankCutoff printString , ')' ].
	aRule producesControlCharacter ifTrue: [
		^ 'raw control-character merge at low rank (' , aRule rank printString , ')' ].
	(aRule isDegeneratePair and: [ (#(#asciiLetter #digit) includes: aRule producedCategory) not ]) ifTrue: [
		^ 'degenerate/duplicate non-alphanumeric pair (' , aRule displayPair , ') at low rank (' , aRule rank printString , ')' ].
	^ nil
]

{ #category : 'querying' }
GcMergeList >> pairIndex [
	^ pairIndex ifNil: [
		pairIndex := Dictionary new.
		self rules do: [ :r | pairIndex at: r pair ifAbsentPut: [ r rank ] ].
		pairIndex ]
]

{ #category : 'printing' }
GcMergeList >> printOn: aStream [
	aStream nextPutAll: 'merge list ('; print: self size; nextPutAll: ' rules)'
]

{ #category : 'querying' }
GcMergeList >> rankForToken: aTokenString [
	"The rank at which a vocab piece was first formed (= the rank of the merge that produced it), or nil for a base byte/piece that is never a merge result."
	^ self rankIndex at: aTokenString ifAbsent: [ nil ]
]

{ #category : 'querying' }
GcMergeList >> rankIndex [
	^ rankIndex ifNil: [
		rankIndex := Dictionary new.
		self rules do: [ :r | rankIndex at: r merged ifAbsentPut: [ r rank ] ].
		rankIndex ]
]

{ #category : 'querying' }
GcMergeList >> rankOfPair: anArray [
	"The rank of the merge whose {left. right} pair equals anArray, or nil."
	^ self pairIndex at: anArray ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GcMergeList >> ruleAt: aRank [
	"The rule at the given 0-based rank (nil if out of range)."
	^ self rules at: aRank + 1 ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GcMergeList >> rules [
	^ rules ifNil: [ #() ]
]

{ #category : 'initialization' }
GcMergeList >> setRules: aCollection [
	rules := aCollection asArray.
	^ self
]

{ #category : 'accessing' }
GcMergeList >> size [
	^ self rules size
]

{ #category : 'suspected merges' }
GcMergeList >> suspectedManualMergeRules [
	"The raw (Array) subset of flagged rules, ordered by rank -- for views on THIS list."
	^ self rules select: [ :r | (self manualMergeReasonFor: r) notNil ]
]

{ #category : 'suspected merges' }
GcMergeList >> suspectedManualMerges [
	"A GcMergeList of the suspected hand-inserted merges (see #manualMergeReasonFor:), carrying this list's low-rank cutoff so per-suspect reasons stay stable when drilling into the result."
	| child |
	child := self class rules: self suspectedManualMergeRules.
	child tokenizer: tokenizer.
	child manualMergeCutoff: self lowRankCutoff.
	^ child
]

{ #category : 'accessing' }
GcMergeList >> tokenizer [
	^ tokenizer
]

{ #category : 'accessing' }
GcMergeList >> tokenizer: aTokenizer [
	tokenizer := aTokenizer
]
