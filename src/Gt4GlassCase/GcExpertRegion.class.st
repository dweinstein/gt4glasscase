"
One winning expert on a router region map's slice: the expert's index, how many grid cells it wins (cellCount of totalCells), and a back-reference to the owning GcMoeRouter. A first-class legend entry (I1) so a click on the 'Expert regions' legend drills into a real domain object (the expert, its router row, its share of the slice) instead of a bare integer. Displays the expert index 0-based to match HuggingFace/safetensors expert numbering.
"
Class {
	#name : 'GcExpertRegion',
	#superclass : 'Object',
	#instVars : [
		'router',
		'expertIndex',
		'cellCount',
		'totalCells'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcExpertRegion class >> router: aRouter expertIndex: anIndex cellCount: aCount totalCells: aTotal [
	^ self new
		setRouter: aRouter expertIndex: anIndex cellCount: aCount totalCells: aTotal;
		yourself
]

{ #category : 'accessing' }
GcExpertRegion >> cellCount [
	^ cellCount
]

{ #category : 'accessing' }
GcExpertRegion >> color [
	^ Color h: (360.0 * (expertIndex - 1) / (router expertCount max: 1)) s: 0.62 v: 0.92
]

{ #category : 'gt - facets' }
GcExpertRegion >> expertFacets [
	^ OrderedCollection new
		add: 'Expert (0-based)' -> self expertIndexZeroBased;
		add: 'Cells won' -> cellCount;
		add: 'Share of slice' -> self sharePercentLabel;
		add: 'Router row L2 norm' -> self rowNorm;
		add: 'Router' -> router;
		yourself
]

{ #category : 'accessing' }
GcExpertRegion >> expertIndex [
	"1-based (Smalltalk array) index of the expert."
	^ expertIndex
]

{ #category : 'accessing' }
GcExpertRegion >> expertIndexZeroBased [
	"0-based expert index, matching HuggingFace/safetensors expert numbering."
	^ expertIndex - 1
]

{ #category : 'accessing' }
GcExpertRegion >> fraction [
	"Share of slice cells this expert wins (0..1)."
	^ totalCells = 0 ifTrue: [ 0 ] ifFalse: [ cellCount / totalCells ]
]

{ #category : 'gt - views' }
GcExpertRegion >> gtExpertFacetsFor: aView [
	"Who is this winning expert and how much of the slice does it own? Rows send the router."
	<gtView>
	^ aView columnedList
		title: 'Expert';
		priority: 10;
		items: [ self expertFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'printing' }
GcExpertRegion >> printOn: aStream [
	aStream
		nextPutAll: 'GcExpertRegion(expert ';
		print: self expertIndexZeroBased;
		nextPutAll: ', ';
		nextPutAll: self sharePercentLabel;
		nextPutAll: ' of slice)'
]

{ #category : 'accessing' }
GcExpertRegion >> router [
	^ router
]

{ #category : 'accessing' }
GcExpertRegion >> routerRow [
	"This expert's row of the router weight matrix (a hiddenSize-vector)."
	^ router weightMatrix at: expertIndex
]

{ #category : 'accessing' }
GcExpertRegion >> rowNorm [
	"L2 norm of this expert's router row."
	^ (self routerRow inject: 0.0 into: [ :s :x | s + (x * x) ]) sqrt
]

{ #category : 'initialization' }
GcExpertRegion >> setRouter: aRouter expertIndex: anIndex cellCount: aCount totalCells: aTotal [
	router := aRouter.
	expertIndex := anIndex.
	cellCount := aCount.
	totalCells := aTotal
]

{ #category : 'accessing' }
GcExpertRegion >> sharePercentLabel [
	^ ((self fraction * 100) asFloat printShowingDecimalPlaces: 1) , '%'
]

{ #category : 'accessing' }
GcExpertRegion >> totalCells [
	^ totalCells
]
