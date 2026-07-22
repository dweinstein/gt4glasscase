"
Executable documentation for GcBehavioralConceptComparison. plantedAgreementAndDisagreementExample is HERMETIC: two GcProbeableStubModel instances made to deliberately DISAGREE on one planted word (via logitOverrides, keyed by that word's exact prompt ids) while AGREEING on another planted word, proving the Agreement/Top-k-overlap data reflects the plant with every probability measurement finite -- no weights, no network, no GPT-2 tokenizer/decoder. gpt2FamilyBehavioralComparisonExample is <noTest>: the real reproducible artifact across gpt2-124M / distilgpt2 / gpt2-medium (gpt2-medium's forward alone takes ~18 minutes -- do not run casually; open the resulting GcBehavioralConceptComparison to explore its views instead).
"
Class {
	#name : 'GcBehavioralConceptComparisonExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'examples' }
GcBehavioralConceptComparisonExamples >> gpt2FamilyBehavioralComparisonExample [
	<gtExample>
	<noTest>
	"The reproducible real artifact: gpt2-124M / distilgpt2 / gpt2-medium compared on the shared 7-word hypernym probe (SEQUENTIAL, memory discipline). gpt2-medium's forward alone takes ~18 minutes -- do not run casually; open the resulting GcBehavioralConceptComparison to explore its Agreement / Top-k overlap / Models views."
	| comparison |
	comparison := GcBehavioralConceptComparison defaultGpt2Family.
	comparison run.
	^ comparison
]

{ #category : 'examples' }
GcBehavioralConceptComparisonExamples >> plantedAgreementAndDisagreementExample [
	<gtExample>
	"HERMETIC: two GcProbeableStubModel instances deliberately made to DISAGREE on one planted word (via logitOverrides, keyed by that word's exact prompt ids) while AGREEING on another planted word. No weights, no network, no GPT-2 tokenizer/decoder. Proves the Agreement data reflects the plant and every measurement is finite."
	| template modelA modelB disagreeIds overrides comparison agreeComparison disagreeComparison |
	template := GcConceptProbe defaultTemplate.
	modelA := GcProbeableStubModel new.
	modelB := GcProbeableStubModel new.
	disagreeIds := (GcConceptProbe word: 'disagreeWord' template: template model: modelA) promptIds.
	overrides := Dictionary new.
	overrides at: disagreeIds asArray put: 7.
	modelB logitOverrides: overrides.
	comparison := GcBehavioralConceptComparison
		words: #('agreeWord' 'disagreeWord')
		template: template
		models: (OrderedCollection new
			add: 'modelA' -> [ modelA ];
			add: 'modelB' -> [ modelB ];
			yourself).
	comparison run.
	self assert: comparison runs size equals: 2.
	agreeComparison := comparison wordComparisonNamed: 'agreeWord'.
	disagreeComparison := comparison wordComparisonNamed: 'disagreeWord'.
	self assert: agreeComparison agree description: 'planted agree word must agree across stubs'.
	self assert: disagreeComparison agree not description: 'planted disagree word must disagree across stubs'.
	comparison wordComparisons do: [ :c |
		c perModelResults do: [ :assoc |
			self assert: (assoc value entriesOrEmpty allSatisfy: [ :e | e prob isNaN not ])
				description: 'finite probs' ] ].
	^ comparison
]
