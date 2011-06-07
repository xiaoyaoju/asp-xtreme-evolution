<script language="Javascript" runat="server">

/*

File: jsonschema.asp

AXE(ASP Xtreme Evolution) JSONSchema validator by Kris Zyp.

JSONSchema.ASP leverages javascript to implement, without any modification, Kris
Zyp validate.js <http://github.com/kriszyp/json-schema/>. AXE documentation and 
examples inserted by Fabio Zendhi Nagao (nagaozen).

License:

This file is part of ASP Xtreme Evolution.
Copyright (C) 2007-2010 Fabio Zendhi Nagao

ASP Xtreme Evolution is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ASP Xtreme Evolution is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with ASP Xtreme Evolution. If not, see <http://www.gnu.org/licenses/>.





Class: JSONSchema

JSON (JavaScript Object Notation) Schema defines the media type
"application/schema+json", a JSON based format for defining the
structure of JSON data.  JSON Schema provides a contract for what
JSON data is required for a given application and how to interact
with it.  JSON Schema is intended to define validation,
documentation, hyperlink navigation, and interaction control of JSON
data.

License:

Copyright (c) 2007 Kris Zyp

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

About:

    - Written by Kris Zyp <http://www.sitepen.com/> @ Nov 2010

Notes:

    - JSONSchema drafts from <http://json-schema.org/>





Function: validate

This method validates a json object against a JSONSchema.

Parameters:

    (object) - a JavaScript object.
    (object) - a JSONSchema object.

Returns:

    (object) - { valid: true|false, errors: [] }.

Example:

(start code)

dim def : def = join(array( _
    "object {", _
    "  string name;", _
    "  string description?;", _
    "  string homepage /^http:/;", _
    "}*;" _
), vbNewline)

dim obj : obj = join(array( _
    "{", _
    "    ""name"": ""Fabio Zendhi Nagao"",", _
    "    ""description"": ""A big enthusiast of programming and mathematics."",", _
    "    ""homepage"": ""http://zend.lojcomm.com.br/""", _
    "}" _
), vbNewline)

Response.write( JSONSchema.validate( JSON.parse(obj), Orderly.parse(def) ).valid )' prints true

(end code)

*/

var JSONSchema = (function() {
    var exports = validate;
    // setup primitive classes to be JSON Schema types
    String.type = "string";
    Boolean.type = "boolean";
    Number.type = "number";
    exports.Integer = {
        type: "integer"
    };
    Object.type = "object";
    Array.type = "array";
    Date.type = "date";
    exports.validate = validate;

    function validate( /*Any*/ instance, /*Object*/ schema) {
        // Summary:
        //  	To use the validator call JSONSchema.validate with an instance object and an optional schema object.
        // 		If a schema is provided, it will be used to validate. If the instance object refers to a schema (self-validating),
        // 		that schema will be used to validate and the schema parameter is not necessary (if both exist,
        // 		both validations will occur).
        // 		The validate method will return an object with two properties:
        // 			valid: A boolean indicating if the instance is valid by the schema
        // 			errors: An array of validation errors. If there are no errors, then an
        // 					empty list will be returned. A validation error will have two properties:
        // 						property: which indicates which property had the error
        // 						message: which indicates what the error was
        //
        return validate(instance, schema, {
            changing: false
        }); //, coerce: false, existingOnly: false});
    };
    
    exports.checkPropertyChange = function( /*Any*/ value, /*Object*/ schema, /*String*/ property) {
        // Summary:
        // 		The checkPropertyChange method will check to see if an value can legally be in property with the given schema
        // 		This is slightly different than the validate method in that it will fail if the schema is readonly and it will
        // 		not check for self-validation, it is assumed that the passed in value is already internally valid.
        // 		The checkPropertyChange method will return the same object type as validate, see JSONSchema.validate for
        // 		information.
        //
        return validate(value, schema, {
            changing: property || "property"
        });
    };
    
    var validate = exports._validate = function( /*Any*/ instance, /*Object*/ schema, /*Object*/ options) {
        if (!options) options = {};
        var _changing = options.changing;
        var errors = [];
        // validate a value against a property definition

        function checkProp(value, schema, path, i) {
            var l;
            path += path ? typeof i == 'number' ? '[' + i + ']' : typeof i == 'undefined' ? '' : '.' + i : i;

            function addError(message) {
                errors.push({
                    property: path,
                    message: message
                });
            }
            if ((typeof schema != 'object' || schema instanceof Array) && (path || typeof schema != 'function') && !(schema && schema.type)) {
                if (typeof schema == 'function') {
                    if (!(value instanceof schema)) {
                        addError("is not an instance of the class/constructor " + schema.name);
                    }
                } else if (schema) {
                    addError("Invalid schema/property definition " + schema);
                }
                return null;
            }
            if (_changing && schema.readonly) {
                addError("is a readonly field, it can not be changed");
            }
            if (schema['extends']) { // if it extends another schema, it must pass that schema as well
                checkProp(value, schema['extends'], path, i);
            }
            // validate a value against a type definition

            function checkType(type, value) {
                if (type) {
                    if (typeof type == 'string' && type != 'any' && (type == 'null' ? value !== null : typeof value != type) && !(value instanceof Array && type == 'array') && !(value instanceof Date && type == 'date') && !(type == 'integer' && value % 1 === 0)) {
                        return [{
                            property: path,
                            message: (typeof value) + " value found, but a " + type + " is required"
                        }];
                    }
                    if (type instanceof Array) {
                        var unionErrors = [];
                        for (var j = 0; j < type.length; j++) { // a union type
                            if (!(unionErrors = checkType(type[j], value)).length) {
                                break;
                            }
                        }
                        if (unionErrors.length) {
                            return unionErrors;
                        }
                    } else if (typeof type == 'object') {
                        var priorErrors = errors;
                        errors = [];
                        checkProp(value, type, path);
                        var theseErrors = errors;
                        errors = priorErrors;
                        return theseErrors;
                    }
                }
                return [];
            }
            if (value === undefined) {
                if (schema.required) {
                    addError("is missing and it is required");
                }
            } else {
                errors = errors.concat(checkType(schema.type, value));
                if (schema.disallow && !checkType(schema.disallow, value).length) {
                    addError(" disallowed value was matched");
                }
                if (value !== null) {
                    if (value instanceof Array) {
                        if (schema.items) {
                            var itemsIsArray = schema.items instanceof Array;
                            var propDef = schema.items;
                            for (i = 0, l = value.length; i < l; i += 1) {
                                if (itemsIsArray) propDef = schema.items[i];
                                if (options.coerce) value[i] = options.coerce(value[i], propDef);
                                errors.concat(checkProp(value[i], propDef, path, i));
                            }
                        }
                        if (schema.minItems && value.length < schema.minItems) {
                            addError("There must be a minimum of " + schema.minItems + " in the array");
                        }
                        if (schema.maxItems && value.length > schema.maxItems) {
                            addError("There must be a maximum of " + schema.maxItems + " in the array");
                        }
                    } else if (schema.properties || schema.additionalProperties) {
                        if(schema.additionalProperties) {
                            schema.additionalProperties = false;
                        }
                        errors.concat(checkObj(value, schema.properties, path, schema.additionalProperties));
                    }
                    if (schema.pattern && typeof value == 'string' && !value.match(schema.pattern)) {
                        addError("does not match the regex pattern " + schema.pattern);
                    }
                    if (schema.maxLength && typeof value == 'string' && value.length > schema.maxLength) {
                        addError("may only be " + schema.maxLength + " characters long");
                    }
                    if (schema.minLength && typeof value == 'string' && value.length < schema.minLength) {
                        addError("must be at least " + schema.minLength + " characters long");
                    }
                    if (typeof schema.minimum !== undefined && typeof value == typeof schema.minimum && schema.minimum > value) {
                        addError("must have a minimum value of " + schema.minimum);
                    }
                    if (typeof schema.maximum !== undefined && typeof value == typeof schema.maximum && schema.maximum < value) {
                        addError("must have a maximum value of " + schema.maximum);
                    }
                    if (schema['enum']) {
                        var enumer = schema['enum'];
                        l = enumer.length;
                        var found;
                        for (var j = 0; j < l; j++) {
                            if (enumer[j] === value) {
                                found = 1;
                                break;
                            }
                        }
                        if (!found) {
                            addError("does not have a value in the enumeration " + enumer.join(", "));
                        }
                    }
                    if (typeof schema.maxDecimal == 'number' && (value.toString().match(new RegExp("\\.[0-9]{" + (schema.maxDecimal + 1) + ",}")))) {
                        addError("may only have " + schema.maxDecimal + " digits of decimal places");
                    }
                }
            }
            return null;
        }
        // validate an object against a schema

        function checkObj(instance, objTypeDef, path, additionalProp) {
            if (typeof objTypeDef == 'object') {
                if (typeof instance != 'object' || instance instanceof Array) {
                    errors.push({
                        property: path,
                        message: "an object is required"
                    });
                }
                for (var i in objTypeDef) {
                    if (objTypeDef.hasOwnProperty(i)) {
                        var value = instance[i];
                        // skip _not_ specified properties
                        if (value === undefined && options.existingOnly) continue;
                        var propDef = objTypeDef[i];
                        // set default
                        if (value === undefined && propDef["default"]) {
                            value = instance[i] = propDef["default"];
                        }
                        if (options.coerce && i in instance) {
                            value = instance[i] = options.coerce(value, propDef);
                        }
                        checkProp(value, propDef, path, i);
                    }
                }
            }
            for (i in instance) {
                if (instance.hasOwnProperty(i) && !(i.charAt(0) == '_' && i.charAt(1) == '_') && objTypeDef && !objTypeDef[i] && additionalProp === false) {
                    if (options.filter) {
                        delete instance[i];
                        continue;
                    } else {
                        errors.push({
                            property: path,
                            message: "The property (" + (typeof value) + ")" + i + " is not defined in the schema and the schema does not allow additional properties"
                        });
                    }
                }
                var requires = objTypeDef && objTypeDef[i] && objTypeDef[i].requires;
                if (requires && !(requires in instance)) {
                    errors.push({
                        property: path,
                        message: "the presence of the property " + i + " requires that " + requires + " also be present"
                    });
                }
                value = instance[i];
                if (additionalProp && (!(objTypeDef && typeof objTypeDef == 'object') || !(i in objTypeDef))) {
                    if (options.coerce) {
                        value = instance[i] = options.coerce(value, additionalProp);
                    }
                    checkProp(value, additionalProp, path, i);
                }
                if (!_changing && value && value.$schema) {
                    errors = errors.concat(checkProp(value, value.$schema, path, i));
                }
            }
            return errors;
        }
        if (schema) {
            checkProp(instance, schema, '', _changing || '');
        }
        if (!_changing && instance && instance.$schema) {
            checkProp(instance, instance.$schema, '', '');
        }
        return {
            valid: !errors.length,
            errors: errors
        };
    };
    exports.mustBeValid = function(result) {
        //	summary:
        //		This checks to ensure that the result is valid and will throw an appropriate error message if it is not
        // result: the result returned from checkPropertyChange or validate
        if (!result.valid) {
            throw new TypeError(result.errors.map(function(error) {
                return "for property " + error.property + ': ' + error.message;
            }).join(", \n"));
        }
    }
    return exports;
})();

</script>