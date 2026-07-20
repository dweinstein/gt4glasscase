"
A group whose items are themselves groups (the result of partitionBy:). Itself a group with its own views, enabling recursive drill-down.
"
Class {
	#name : 'GcGroupOfGroups',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'small multiples' }
GcGroupOfGroups >> defaultCohortStencil [
	^ GcCohortStencil default
]

{ #category : 'gt - views' }
GcGroupOfGroups >> gtOverviewFor: aView [
	"Drill-down overview: one row per inner group with its label, size and a headline number; click a row to open that group's own views (recursive drill-down without leaving the inspector)."
	<gtView>
	^ aView columnedList
		title: 'Overview';
		priority: 4;
		items: [ self items ];
		column: 'Group' text: [ :g | g printString ];
		column: 'Size' text: [ :g | g size printString ];
		column: 'Headline' text: [ :g | g headline ];
		send: [ :g | g ]
]

{ #category : 'views' }
GcGroupOfGroups >> gtSmallMultiplesFor: aView [
	<gtView>
	"Which cohort breaks the visual texture of its siblings?"
	^ self smallMultiplesViewFor: aView stencil: self defaultCohortStencil
]

{ #category : 'views' }
GcGroupOfGroups >> gtSubgroupsFor: aView [
	"What are the partitions, and how big is each?"
	<gtView>
	^ aView columnedList
		title: 'Subgroups';
		priority: 5;
		items: [ self items ];
		column: 'Group' text: [ :g | g printString ];
		column: 'Size' text: [ :g | g size printString ]
]

{ #category : 'small multiples' }
GcGroupOfGroups >> smallMultiplesViewFor: aView stencil: aStencil [
	| context |
	context := aStencil contextFor: self.
	^ aView mondrian
		title: 'Small multiples';
		priority: 6;
		painting: [ :m |
			m nodes
				stencil: [ :childGroup | aStencil elementFor: childGroup context: context ];
				with: self items.
			m layout grid ]
]
