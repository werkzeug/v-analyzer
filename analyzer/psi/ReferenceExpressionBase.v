module psi

pub interface ReferenceExpressionBase {
	Expression
	name() string
	qualifier() ?PsiElement
	reference() PsiReference
	resolve_local() ?PsiElement
}