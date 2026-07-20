"
The computed tessellation of a GcHiddenSlice by a GcMoeRouter: an N x N grid of winning-expert indices (argmaxGrid) plus the piecewise-linear max-logit surface (surfaceGrid) -- Thomas Dullien's ReLU/argmax fold, made exact by the MoE router. Precomputes the per-slice constants cu=W.u, cv=W.v, cb=W.base(+bias) ONCE, so each grid cell costs `expertCount` adds/mults (NOT expertCount x hidden). All computation is CPU-only over already-decoded weights (no network in views, I5). Views: 'Expert regions' (categorical tessellation), 'Routing surface' (grayscale fold), 'Quantization shift' (cells that reroute under SIMULATED int4 RTN -- the security-relevant view). Every caption states honestly: this is a 2D SLICE (basis named) of high-dim space, the quant view is simulated symmetric RTN not the real codebook, and it is router-input geometry independent of real activations.
"
Class {
	#name : 'GcRouterRegionMap',
	#superclass : 'Object',
	#instVars : [
		'router',
		'slice',
		'cu',
		'cv',
		'cb',
		'argmaxGrid',
		'surfaceGrid'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcRouterRegionMap class >> router: aRouter slice: aSlice [
	^ self new
		setRouter: aRouter slice: aSlice;
		yourself
]

{ #category : 'computing - grids' }
GcRouterRegionMap >> argmaxGrid [
	"N x N Array of Arrays: the 1-based winning-expert index at each grid cell."
	^ argmaxGrid ifNil: [ self computeGrids. argmaxGrid ]
]

{ #category : 'rendering - elements' }
GcRouterRegionMap >> captionElement: aString [
	^ BlTextElement new
		text: aString asRopedText;
		padding: (BlInsets all: 4);
		yourself
]

{ #category : 'computing - constants' }
GcRouterRegionMap >> cb [
	"W . base (+ bias) : the per-expert offset at the slice origin. Computed once."
	^ cb ifNil: [
		| wb |
		wb := router matrixTimesVector: slice base.
		router bias ifNotNil: [ wb := (1 to: router expertCount) collect: [ :e | (wb at: e) + (router bias at: e) ] ].
		cb := wb ]
]

{ #category : 'querying' }
GcRouterRegionMap >> cellCounts [
	"Expert index -> number of grid cells it wins."
	| counts |
	counts := Dictionary new.
	self argmaxGrid do: [ :row | row do: [ :e | counts at: e put: (counts at: e ifAbsent: [ 0 ]) + 1 ] ].
	^ counts
]

{ #category : 'rendering - private' }
GcRouterRegionMap >> cellPixels [
	"Pixels per grid cell in the rendered raster (baked in so no smoothing/scaling is needed)."
	^ 3
]

{ #category : 'rendering - colors' }
GcRouterRegionMap >> colorForExpert: anExpertIndex [
	"A categorical hue for the 1-based expert index. With many experts index->hue shows region STRUCTURE, not exact identity."
	| hue |
	hue := 360.0 * (anExpertIndex - 1) / (router expertCount max: 1).
	^ Color h: hue s: 0.62 v: 0.92
]

{ #category : 'computing - grids' }
GcRouterRegionMap >> computeGrids [
	"Fill both the argmax grid (winning expert per cell) and the max-logit surface grid in one pass. Per cell cost = expertCount (uses precomputed cu, cv, cb)."
	| n theCu theCv theCb theExperts argGrid surfGrid |
	n := slice resolution.
	theExperts := router expertCount.
	theCu := self cu.
	theCv := self cv.
	theCb := self cb.
	argGrid := Array new: n.
	surfGrid := Array new: n.
	1 to: n do: [ :j |
		| b argRow surfRow |
		b := slice bAt: j.
		argRow := Array new: n.
		surfRow := Array new: n.
		1 to: n do: [ :i |
			| a best bestIndex |
			a := slice aAt: i.
			best := (a * (theCu at: 1)) + (b * (theCv at: 1)) + (theCb at: 1).
			bestIndex := 1.
			2 to: theExperts do: [ :e |
				| val |
				val := (a * (theCu at: e)) + (b * (theCv at: e)) + (theCb at: e).
				val > best ifTrue: [ best := val. bestIndex := e ] ].
			argRow at: i put: bestIndex.
			surfRow at: i put: best ].
		argGrid at: j put: argRow.
		surfGrid at: j put: surfRow ].
	argmaxGrid := argGrid.
	surfaceGrid := surfGrid
]

{ #category : 'computing - constants' }
GcRouterRegionMap >> cu [
	"W . u : the per-expert response to the first slice axis. Computed once."
	^ cu ifNil: [ cu := router matrixTimesVector: slice u ]
]

{ #category : 'computing - constants' }
GcRouterRegionMap >> cv [
	"W . v : the per-expert response to the second slice axis. Computed once."
	^ cv ifNil: [ cv := router matrixTimesVector: slice v ]
]

{ #category : 'querying' }
GcRouterRegionMap >> distinctWinningExperts [
	"The set of expert indices that win at least one cell on this slice -- a legibility metric (1 = degenerate)."
	| experts |
	experts := Set new.
	self argmaxGrid do: [ :row | row do: [ :e | experts add: e ] ].
	^ experts
]

{ #category : 'querying' }
GcRouterRegionMap >> expertRegions [
	"One GcExpertRegion per distinct winning expert (I1: legend rows are domain objects, not bare integers), sorted by descending cell share."
	| counts total |
	counts := self cellCounts.
	total := self totalCells.
	^ (counts associations asSortedCollection: [ :x :y | x value >= y value ]) asArray
		collect: [ :assoc |
			GcExpertRegion
				router: router
				expertIndex: assoc key
				cellCount: assoc value
				totalCells: total ]
]

{ #category : 'rendering - captions' }
GcRouterRegionMap >> expertRegionsCaption [
	| s |
	s := WriteStream on: String new.
	s nextPutAll: 'Expert regions - router L'; nextPutAll: router layerLabel; nextPutAll: ', '; print: router expertCount; nextPutAll: ' experts, d='; print: router hiddenSize; cr.
	s nextPutAll: '2D SLICE of hidden space; basis: '; nextPutAll: slice basisLabel; nextPutAll: '; a,b in '; nextPutAll: slice extentLabel; cr.
	s nextPutAll: 'Colour = winning (argmax) expert. Router-input geometry only:'; cr.
	s nextPutAll: 'NOT the global partition, NOT real activations. Distinct experts here: '; print: self distinctWinningExperts size; nextPutAll: ' of '; print: router expertCount; nextPutAll: '.'.
	^ s contents
]

{ #category : 'rendering - elements' }
GcRouterRegionMap >> expertRegionsElement [
	^ self rasterElementWithCaption: self expertRegionsCaption form: self regionRasterForm
]

{ #category : 'quantization' }
GcRouterRegionMap >> flipCountAgainst: anotherMap [
	"Number of grid cells whose winning expert differs between the two maps (must share resolution)."
	| n mine other count |
	n := slice resolution.
	mine := self argmaxGrid.
	other := anotherMap argmaxGrid.
	count := 0.
	1 to: n do: [ :j |
		| r1 r2 |
		r1 := mine at: j.
		r2 := other at: j.
		1 to: n do: [ :i | (r1 at: i) = (r2 at: i) ifFalse: [ count := count + 1 ] ] ].
	^ count
]

{ #category : 'quantization' }
GcRouterRegionMap >> flipFractionAgainst: anotherMap [
	"Fraction (0..1) of grid cells that reroute between the two maps."
	^ (self flipCountAgainst: anotherMap) / self totalCells
]

{ #category : 'rendering - colors' }
GcRouterRegionMap >> grayForSurfaceValue: aValue min: aMin max: aMax [
	"Grayscale height shade: min -> black, max -> white."
	| range t |
	range := aMax - aMin.
	t := range = 0 ifTrue: [ 0.5 ] ifFalse: [ (aValue - aMin) / range ].
	^ Color gray: t asFloat
]

{ #category : 'gt - views' }
GcRouterRegionMap >> gtExpertRegionsFor: aView [
	"Which experts does the router route to across this 2D slice, and how is the space carved up? The argmax tessellation coloured by winning expert."
	<gtView>
	^ aView explicit
		title: 'Expert regions';
		priority: 10;
		stencil: [ self expertRegionsElement ]
]

{ #category : 'gt - views' }
GcRouterRegionMap >> gtMapFacetsFor: aView [
	"The provenance and summary of this tessellation. Rows send the router / slice domain objects."
	<gtView>
	^ aView columnedList
		title: 'Region map';
		priority: 50;
		items: [ self mapFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcRouterRegionMap >> gtQuantizationShiftFor: aView [
	"How much does routing move under simulated int4? Cells that reroute (red) over the faded base tessellation -- the mechanism behind quantization-conditional routing anomalies."
	<gtView>
	^ aView explicit
		title: 'Quantization shift';
		priority: 30;
		stencil: [ self quantizationShiftElementBits: 4 ]
]

{ #category : 'gt - views' }
GcRouterRegionMap >> gtRoutingSurfaceFor: aView [
	"What does the router's folded decision surface look like? The piecewise-linear max-logit height as grayscale (Dullien's picture)."
	<gtView>
	^ aView explicit
		title: 'Routing surface';
		priority: 20;
		stencil: [ self routingSurfaceElement ]
]

{ #category : 'gt - views' }
GcRouterRegionMap >> gtWinningExpertsFor: aView [
	"Which experts win, and what share of the slice each takes. Click a row to inspect that expert region."
	<gtView>
	^ aView columnedList
		title: 'Winning experts';
		priority: 40;
		items: [ self expertRegions ];
		column: 'Expert' text: [ :region | region expertIndexZeroBased ];
		column: 'Cells' text: [ :region | region cellCount ];
		column: 'Share' text: [ :region | region sharePercentLabel ];
		send: [ :region | region ]
]

{ #category : 'gt - facets' }
GcRouterRegionMap >> mapFacets [
	^ OrderedCollection new
		add: 'Router' -> router;
		add: 'Slice' -> slice;
		add: 'Experts (E)' -> router expertCount;
		add: 'Distinct winning experts' -> self distinctWinningExperts size;
		add: 'Grid' -> (slice resolution printString , ' x ' , slice resolution printString);
		add: 'a,b range' -> slice extentLabel;
		add: 'Simulated int4 flip fraction' -> (self quantizationFlipFractionToBits: 4) asFloat;
		yourself
]

{ #category : 'printing' }
GcRouterRegionMap >> printOn: aStream [
	aStream
		nextPutAll: 'GcRouterRegionMap(';
		print: slice resolution;
		nextPutAll: 'x';
		print: slice resolution;
		nextPutAll: ', ';
		print: self distinctWinningExperts size;
		nextPutAll: '/';
		print: router expertCount;
		nextPutAll: ' experts win)'
]

{ #category : 'rendering - captions' }
GcRouterRegionMap >> quantShiftCaptionBits: nBits flip: aFraction [
	| s |
	s := WriteStream on: String new.
	s nextPutAll: 'Quantization shift - router L'; nextPutAll: router layerLabel; cr.
	s nextPutAll: ((aFraction * 100) asFloat printShowingDecimalPlaces: 2); nextPutAll: '% of grid cells reroute under SIMULATED symmetric int'; print: nBits; nextPutAll: ' RTN (per-row).'; cr.
	s nextPutAll: 'MECHANISM demonstration only -- NOT the model''s real GGUF codebook.'; cr.
	s nextPutAll: 'Red = flipped cell; faded = unchanged base tessellation. Basis: '; nextPutAll: slice basisLabel; nextPutAll: '.'.
	^ s contents
]

{ #category : 'quantization' }
GcRouterRegionMap >> quantizationFlipFractionToBits: nBits [
	"Fraction of slice cells that reroute under simulated int-nBits RTN. The security-relevant scalar."
	^ self flipFractionAgainst: (self quantizedMapToBits: nBits)
]

{ #category : 'rendering - elements' }
GcRouterRegionMap >> quantizationShiftElementBits: nBits [
	| qmap flip |
	qmap := self quantizedMapToBits: nBits.
	flip := self flipFractionAgainst: qmap.
	^ self rasterElementWithCaption: (self quantShiftCaptionBits: nBits flip: flip) form: (self shiftRasterFormAgainst: qmap)
]

{ #category : 'quantization' }
GcRouterRegionMap >> quantizedMapToBits: nBits [
	"The region map of this router's simulated int-nBits quantization on the SAME slice, so the two argmax grids are directly comparable."
	^ GcRouterRegionMap router: (router quantizedToBits: nBits) slice: slice
]

{ #category : 'rendering - elements' }
GcRouterRegionMap >> rasterElementWithCaption: aCaptionString form: aForm [
	| caption raster |
	caption := self captionElement: aCaptionString.
	raster := BlFormElement new form: aForm.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 6);
		addChildren: { caption. raster };
		yourself
]

{ #category : 'rendering - forms' }
GcRouterRegionMap >> regionRasterForm [
	"A Form coloured by winning expert per cell (cellPixels x cellPixels blocks, no scaling needed)."
	| n cell form |
	n := slice resolution.
	cell := self cellPixels.
	form := Form extent: (n * cell) @ (n * cell) depth: 32.
	1 to: n do: [ :j |
		| argRow |
		argRow := self argmaxGrid at: j.
		1 to: n do: [ :i |
			form
				fill: (((i - 1) * cell) @ ((j - 1) * cell) extent: cell @ cell)
				fillColor: (self colorForExpert: (argRow at: i)) ] ].
	^ form
]

{ #category : 'accessing' }
GcRouterRegionMap >> router [
	^ router
]

{ #category : 'rendering - elements' }
GcRouterRegionMap >> routingSurfaceElement [
	^ self rasterElementWithCaption: self surfaceCaption form: self surfaceRasterForm
]

{ #category : 'initialization' }
GcRouterRegionMap >> setRouter: aRouter slice: aSlice [
	router := aRouter.
	slice := aSlice
]

{ #category : 'rendering - forms' }
GcRouterRegionMap >> shiftRasterFormAgainst: anotherMap [
	"A Form of the base tessellation faded, with cells that reroute under anotherMap painted red."
	| n cell form mine other |
	n := slice resolution.
	cell := self cellPixels.
	mine := self argmaxGrid.
	other := anotherMap argmaxGrid.
	form := Form extent: (n * cell) @ (n * cell) depth: 32.
	1 to: n do: [ :j |
		| r1 r2 |
		r1 := mine at: j.
		r2 := other at: j.
		1 to: n do: [ :i |
			| c |
			c := (r1 at: i) = (r2 at: i)
				ifTrue: [ (self colorForExpert: (r1 at: i)) mixed: 0.28 with: Color white ]
				ifFalse: [ Color red ].
			form fill: (((i - 1) * cell) @ ((j - 1) * cell) extent: cell @ cell) fillColor: c ] ].
	^ form
]

{ #category : 'accessing' }
GcRouterRegionMap >> slice [
	^ slice
]

{ #category : 'rendering - captions' }
GcRouterRegionMap >> surfaceCaption [
	| s |
	s := WriteStream on: String new.
	s nextPutAll: 'Routing surface - max-logit f(a,b) = max_e (W.h)_e, router L'; nextPutAll: router layerLabel; cr.
	s nextPutAll: 'Piecewise-linear folded surface (ReLU/argmax fold, exact for the MoE router).'; cr.
	s nextPutAll: 'Grayscale height: black = low, white = high. 2D SLICE; basis: '; nextPutAll: slice basisLabel; nextPutAll: '.'.
	^ s contents
]

{ #category : 'computing - grids' }
GcRouterRegionMap >> surfaceGrid [
	"N x N Array of Arrays: the max-logit value (folded surface height) at each grid cell."
	^ surfaceGrid ifNil: [ self computeGrids. surfaceGrid ]
]

{ #category : 'querying' }
GcRouterRegionMap >> surfaceMax [
	| m |
	m := (self surfaceGrid at: 1) at: 1.
	self surfaceGrid do: [ :row | row do: [ :val | val > m ifTrue: [ m := val ] ] ].
	^ m
]

{ #category : 'querying' }
GcRouterRegionMap >> surfaceMin [
	| m |
	m := (self surfaceGrid at: 1) at: 1.
	self surfaceGrid do: [ :row | row do: [ :val | val < m ifTrue: [ m := val ] ] ].
	^ m
]

{ #category : 'rendering - forms' }
GcRouterRegionMap >> surfaceRasterForm [
	"A grayscale Form of the max-logit surface (Dullien's folded picture)."
	| n cell form mn mx |
	n := slice resolution.
	cell := self cellPixels.
	mn := self surfaceMin.
	mx := self surfaceMax.
	form := Form extent: (n * cell) @ (n * cell) depth: 32.
	1 to: n do: [ :j |
		| srow |
		srow := self surfaceGrid at: j.
		1 to: n do: [ :i |
			form
				fill: (((i - 1) * cell) @ ((j - 1) * cell) extent: cell @ cell)
				fillColor: (self grayForSurfaceValue: (srow at: i) min: mn max: mx) ] ].
	^ form
]

{ #category : 'querying' }
GcRouterRegionMap >> totalCells [
	^ slice resolution * slice resolution
]
