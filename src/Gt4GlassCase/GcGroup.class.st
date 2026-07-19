"
Abstract base for every Glass Case group (I2: groups are first-class, not Collection of:). Uses TGtGroupWithItems for the collection protocol (items, do:, size, groupedBy:, ...) and adds a GcDerivation so lineage is never broken (I3). select:/reject:/partitionBy:/varyingAxis:/sample:/outliersBy: return groups that record how they were made.
"
Class {
	#name : 'GcGroup',
	#superclass : 'Object',
	#traits : 'TGtGroupWithItems',
	#classTraits : 'TGtGroupWithItems classTrait',
	#instVars : [
		'derivation'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'operations' }
GcGroup >> compareTo: anotherGroup [
	^ GcGroupComparison left: self right: anotherGroup
]

{ #category : 'accessing' }
GcGroup >> derivation [
	^ derivation
]

{ #category : 'accessing' }
GcGroup >> derivation: aDerivation [
	derivation := aDerivation
]

{ #category : 'accessing' }
GcGroup >> derivationChain [
	"The operations from this group back to a root, most recent first."
	| ops g |
	ops := OrderedCollection new.
	g := self.
	[ g notNil and: [ g derivation notNil ] ] whileTrue: [
		ops add: g derivation operation.
		g := g derivation parent ].
	^ ops
]

{ #category : 'views' }
GcGroup >> gtDerivationFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Derivation';
		priority: 20;
		items: [ self derivationChain ];
		column: 'Operation' text: [ :op | op asString ]
]

{ #category : 'views' }
GcGroup >> gtItemsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Items';
		priority: 10;
		items: [ self items ];
		column: 'Item' text: [ :each | each printString ]
]

{ #category : 'testing' }
GcGroup >> isRoot [
	^ derivation isNil
]

{ #category : 'analyzing' }
GcGroup >> noiseFloor [
	"Seed-only variance within this group. Meaningful for completion/slice groups (Layer D); nil at the base."
	^ nil
]

{ #category : 'operations' }
GcGroup >> outliersBy: aBlock [
	"A subgroup of items whose value under aBlock is more than 2 standard deviations from the group mean; lineage preserved."
	| values mean variance std |
	values := self items collect: [ :each | (aBlock value: each) asFloat ].
	values isEmpty ifTrue: [ ^ self withItems: #() derivedBy: #outliersBy: ].
	mean := (values inject: 0.0 into: [ :s :v | s + v ]) / values size.
	variance := (values inject: 0.0 into: [ :s :v | s + (v - mean) squared ]) / values size.
	std := variance sqrt.
	^ self withItems: (self items select: [ :each |
		std = 0
			ifTrue: [ false ]
			ifFalse: [ ((aBlock value: each) asFloat - mean) abs / std > 2 ] ]) derivedBy: #outliersBy:
]

{ #category : 'operations' }
GcGroup >> partitionBy: aBlock [
	"Partition into cohorts by aBlock, yielding a GcGroupOfGroups whose items are same-species subgroups, each with its own lineage."
	| partitions |
	partitions := self groupedBy: aBlock.
	partitions valuesDo: [ :each |
		each derivation: (GcDerivation parent: self operation: #partitionBy:) ].
	^ (GcGroupOfGroups withAll: partitions values)
		derivation: (GcDerivation parent: self operation: #partitionBy:);
		yourself
]

{ #category : 'enumerating' }
GcGroup >> reject: aBlock [
	^ self withItems: (self items reject: aBlock) derivedBy: #reject:
]

{ #category : 'operations' }
GcGroup >> sample: anInteger [
	"A reproducible sample of anInteger items using a default seed."
	^ self sample: anInteger seed: 42
]

{ #category : 'operations' }
GcGroup >> sample: anInteger seed: aSeedInteger [
	"A reproducible, seeded sample; the seed is recorded on the derivation."
	| random pool picked |
	random := Random seed: aSeedInteger.
	pool := OrderedCollection withAll: self items.
	picked := OrderedCollection new.
	[ picked size < anInteger and: [ pool isNotEmpty ] ] whileTrue: [
		picked add: (pool removeAt: (random nextInteger: pool size)) ].
	^ self
		withItems: picked
		derivedBy: #sample:
		parameters: (Dictionary new at: #seed put: aSeedInteger; at: #n put: anInteger; yourself)
]

{ #category : 'enumerating' }
GcGroup >> select: aBlock [
	"Overrides the trait to preserve lineage (I3): the result is a group that records it came from self by #select:."
	^ self withItems: (self items select: aBlock) derivedBy: #select:
]

{ #category : 'analyzing' }
GcGroup >> statistics [
	"A type-appropriate summary object. Base: item count; subclasses enrich."
	^ Dictionary new
		at: #count put: self size;
		yourself
]

{ #category : 'operations' }
GcGroup >> varyingAxis: anAxisName [
	"Partition into cohorts that differ only along anAxisName (all other coordinate axes held fixed), returning a GcSliceGroup -- the raw material for every divergence test. Items must answer #coordinate."
	| cohorts |
	cohorts := self groupedBy: [ :each | each coordinate withoutAxis: anAxisName ].
	cohorts valuesDo: [ :each |
		each derivation: (GcDerivation parent: self operation: #varyingAxis:) ].
	^ (GcSliceGroup withAll: cohorts values)
		varyingAxis: anAxisName;
		derivation: (GcDerivation
			parent: self
			operation: #varyingAxis:
			parameters: (Dictionary new at: #axis put: anAxisName; yourself));
		yourself
]

{ #category : 'private' }
GcGroup >> withItems: aCollection derivedBy: anOperation [
	^ self withItems: aCollection derivedBy: anOperation parameters: Dictionary new
]

{ #category : 'private' }
GcGroup >> withItems: aCollection derivedBy: anOperation parameters: aDictionary [
	"Build a child group of the same species holding aCollection, stamped with how it was made."
	| child |
	child := self species withAll: aCollection.
	child derivation: (GcDerivation parent: self operation: anOperation parameters: aDictionary).
	^ child
]
