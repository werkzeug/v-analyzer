module providers

import analyzer.psi
import lsp
import strings
import lserver.completion

pub struct ReferenceCompletionProcessor {
	file       &psi.PsiFileImpl
	module_fqn string
	root       string
	ctx        &completion.CompletionContext
mut:
	result []lsp.CompletionItem
}

pub fn (mut c ReferenceCompletionProcessor) elements() []lsp.CompletionItem {
	return c.result
}

fn (mut c ReferenceCompletionProcessor) is_local_resolve(element psi.PsiElement) bool {
	equal := c.module_fqn == element.containing_file.module_fqn()
	if equal && c.module_fqn == 'main' {
		// Мы проверяем что модуль совпадает, но если это main, то надо проверить что
		// файл находится в workspace.
		return element.containing_file.path.starts_with(c.root)
	}
	return equal
}

fn (mut c ReferenceCompletionProcessor) execute(element psi.PsiElement) bool {
	is_public, name := if element is psi.PsiNamedElement {
		element.is_public(), element.name()
	} else {
		true, ''
	}
	local_resolve := c.is_local_resolve(element)

	if !is_public && !local_resolve {
		return true
	}

	if element is psi.VarDefinition {
		c.result << lsp.CompletionItem{
			label: name
			kind: .variable
			detail: element.get_type().readable_name()
			documentation: ''
			insert_text: name
			insert_text_format: .plain_text
			sort_text: '0${name}' // чтобы переменные шли первыми
		}
	}

	if element is psi.ParameterDeclaration {
		c.result << lsp.CompletionItem{
			label: name
			kind: .variable
			detail: element.get_type().readable_name()
			documentation: ''
			insert_text: name
			insert_text_format: .plain_text
			sort_text: '0${name}' // чтобы параметры шли первыми
		}
	}

	if element is psi.Receiver {
		c.result << lsp.CompletionItem{
			label: element.name()
			kind: .variable
			detail: element.get_type().readable_name()
			documentation: ''
			insert_text: element.name()
			insert_text_format: .plain_text
		}
	}

	if element is psi.FunctionOrMethodDeclaration {
		receiver_text := if receiver := element.receiver() {
			receiver.get_text() + ' '
		} else {
			''
		}

		mut insert_name := element.name()
		if name.starts_with('$') {
			insert_name = insert_name[1..]
		}

		signature := element.signature() or { return true }
		has_params := signature.parameters().len > 0

		mut insert_text_builder := strings.new_builder(20)
		insert_text_builder.write_string(insert_name)
		if has_params {
			insert_text_builder.write_string('($1)')
		} else {
			insert_text_builder.write_string('()')
		}
		insert_text_builder.write_string('$0')

		c.result << lsp.CompletionItem{
			label: '${name}()'
			kind: if receiver_text == '' { .function } else { .method }
			detail: 'fn ${receiver_text}${element.name()}${signature.get_text()}'
			documentation: element.doc_comment()
			insert_text: insert_text_builder.str()
			insert_text_format: .snippet
			sort_text: '1${name}' // чтобы функции шли вторыми
		}
	}

	if element is psi.StructDeclaration {
		if name == 'map' || name == 'array' {
			// создавать напрямую эти структуры не имеет смысла
			return true
		}

		insert_text := if c.ctx.is_type_reference {
			name // если это ссылка на тип, то вставляем только имя
		} else {
			name + '{$1}$0'
		}

		c.result << lsp.CompletionItem{
			label: name
			kind: .struct_
			detail: ''
			documentation: element.doc_comment()
			insert_text: insert_text
			insert_text_format: .snippet
		}
	}

	if element is psi.ConstantDefinition {
		c.result << lsp.CompletionItem{
			label: element.name()
			kind: .constant
			detail: element.get_type().readable_name()
			documentation: element.doc_comment()
			insert_text: element.name()
			insert_text_format: .plain_text
		}
	}

	if element is psi.FieldDeclaration {
		c.result << lsp.CompletionItem{
			label: element.name()
			kind: .field
			detail: element.get_type().readable_name()
			documentation: ''
			insert_text: element.name()
			insert_text_format: .plain_text
		}
	}

	if element is psi.InterfaceMethodDeclaration {
		signature := element.signature() or { return true }
		c.result << lsp.CompletionItem{
			label: element.name() + '()'
			kind: .method
			detail: 'fn ${element.name()}${signature.get_text()}'
			documentation: element.doc_comment()
			insert_text: element.name() + '($1)$0'
			insert_text_format: .snippet
		}
	}

	if element is psi.EnumFieldDeclaration {
		c.result << lsp.CompletionItem{
			label: element.name()
			kind: .enum_member
			detail: ''
			documentation: ''
			insert_text: element.name()
			insert_text_format: .plain_text
		}
	}

	return true
}