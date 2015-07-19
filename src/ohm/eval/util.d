module ohm.eval.util;


import ir = volt.ir.ir;
import volt.token.location : Location;


ir.Function createSimpleFunction(string name)
{
	Location location;
	location.filename = name;
	return createSimpleFunction(location, name);
}


ir.Function createSimpleFunction(Location location, string name)
{
	auto fn = new ir.Function();
	fn.name = name;
	fn.location = location;
	fn.type = new ir.FunctionType();
	fn.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
	fn.type.ret.location = fn.location;
	fn.params = [];
	fn.type.location = fn.location;
	fn._body = new ir.BlockStatement();
	return fn;
}


ir.QualifiedName createQualifiedName(Location location, string[] identifiers, bool leadingDot = false)
{
	auto qname = new ir.QualifiedName();
	qname.identifiers.length = identifiers.length;
	foreach (size_t i, ident; identifiers) {
		qname.identifiers[i] = new ir.Identifier();
		qname.identifiers[i].location = location;
		qname.identifiers[i].value = ident;
	}
	qname.leadingDot = leadingDot;
	return qname;
}


ir.Module createSimpleModule(string[] identifiers)
{
	Location location;
	location.filename = identifiers[$-1];
	return createSimpleModule(location, identifiers);
}


ir.Module createSimpleModule(Location location, string[] identifiers)
{
	auto mod = new ir.Module();
	mod.location = location;
	mod.name = createQualifiedName(location, identifiers);
	mod.children = new ir.TopLevelBlock();
	return mod;
}


ir.Import createImport(Location location, string[] name, bool _static = false)
{
	auto _import = new ir.Import();
	_import.location = location;
	_import.name = createQualifiedName(location, name);
	_import.isStatic = _static;
	return _import;
}


ir.Import addImport(ir.Module mod, string[] name, bool _static = false)
{
	auto _import = createImport(mod.location, name, _static);
	mod.children.nodes ~= _import;
	return _import;
}


ir.Import addImport(Location location, ir.Module mod, string[] name, bool _static = false)
{
	auto _import = createImport(location, name, _static);
	mod.children.nodes ~= _import;
	return _import;
}
