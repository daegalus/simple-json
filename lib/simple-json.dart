import 'dart:mirrors';
import 'dart:convert';

main() {
  List testOthers = [new TestOther.init("112", 3), new TestOther.init("113", 4)];
  Test test = new Test.init("sss", "v", 1, 2.0, true, new List.filled(3, 5), {"test": "Test"}, new TestOther.init("111", 2), testOthers);
  var json = new SimpleJSON<Test>().marshal(test);
  print(json);
  print(new SimpleJSON<Test>().unmarshal(json));
}

class SimpleJSON<T> {
  String marshal(Object obj) {
    return JSON.encode(_marshal(obj));
  }

  Map _marshal(Object obj) {
    InstanceMirror objIM = reflect(obj);
    ClassMirror objCM = objIM.type;
    Set<DeclarationMirror> objDeclarations = objCM.declarations.values.toSet();

    Map<String, Object> jsonMap = new Map<String, Object>();
    Set<DeclarationMirror> objVariables = objDeclarations.where((dmirror) => dmirror.toString().contains("VariableMirror")).toSet();

    objVariables.forEach((variable) {
      var name = _formatKeyToSnake(MirrorSystem.getName(variable.simpleName));
      var reflectee = objIM.getField(variable.simpleName).reflectee;

      if (_isPrimitive(reflectee)) {
        jsonMap[name] = reflectee;
      }
      else if (reflectee is List) {
        if (_isPrimitive(reflectee[0])) jsonMap[name] = reflectee;
        else jsonMap[name] = (reflectee as List).map((elem) => _marshal(elem)).toList();

      }
      else if (reflectee is Map) {
          if (_isPrimitive((reflectee as Map).values.toList()[0])) jsonMap[name] = reflectee;
          else {
            Map<String, Object> map = new Map();
            (reflectee as Map).forEach((key, value) => map[key] = _marshal(value));
            jsonMap[name] = map;
          }
      }
      else {
        jsonMap[name] = _marshal(reflectee);
      }
    });

    return jsonMap;
  }

  T unmarshal(String json, {T existingObject: null}) {
    Map<String, Object> jsonMap = JSON.decode(json);

    ClassMirror cm = reflectClass(T);
    Set<Symbol> objVariables = cm.declarations.keys.where((dmirror) => dmirror.toString().contains("VariableMirror")).toSet();
    T newInstance = cm.newInstance(new Symbol(""), new List()).reflectee;
    InstanceMirror im = reflect(newInstance);

    jsonMap.forEach((key, value) {
      var name = _formatKeyFromSnake(key);
      var reflectee = im.getField(new Symbol(name)).reflectee;
      var fieldMirror = im.getField(new Symbol(name));
      var fieldType = fieldMirror.type;

      if (_isPrimitive(value) && reflectType(value.runtimeType).isAssignableTo(fieldType)) {
        im.setField(new Symbol(name), value);
      }
      else if (value is List && reflectType(value.runtimeType).isAssignableTo(fieldType)) {
        var genericType = cm.instanceMembers[new Symbol(name)].returnType.typeArguments[0];
        if (_isPrimitiveSymbol(genericType.simpleName)) {
          im.setField(new Symbol(name), value);
        }
        else {
          var genType = (genericType as ClassMirror);
          List typedList = (value as List).map((Map val) {
            var genInstance = genType.newInstance(new Symbol(""), new List());
            val.forEach((key, val) {
              genInstance.setField(new Symbol(_formatKeyFromSnake(key)), val);
            });
            return genInstance.reflectee;
          }).toList();
          im.setField(new Symbol(name), typedList);
        }
      }
      else if (value is Map && MirrorSystem.getName(cm.instanceMembers[new Symbol(name)].returnType.simpleName) == "Map") {
          var genericType = cm.instanceMembers[new Symbol(name)].returnType.typeArguments[1];
          if (_isPrimitiveSymbol(genericType.simpleName)) {
            im.setField(new Symbol(name), value);
          }
          else {
            print(genericType);
            var genType = (genericType as ClassMirror);
            var innerMap = new Map();

            (value as Map).forEach((key, val) {
              var genInstance = genType.newInstance(new Symbol(""), new List());
              val.forEach((key, val) {
                print(new Symbol(_formatKeyFromSnake(key)));
                print(val);
                genInstance.setField(new Symbol(_formatKeyFromSnake(key)), val);
              });
              innerMap[key] = genInstance.reflectee;
            });
            im.setField(new Symbol(name), innerMap);
          }
      }
      else {

      }
    });
    return newInstance;
  }

  bool _isPrimitive(Object obj) {
    return obj is String ||
           obj is int ||
           obj is double ||
           obj is bool;
  }

  bool _isPrimitiveSymbol(Symbol symbol) {
    return symbol == new Symbol("int") ||
           symbol == new Symbol("double") ||
           symbol == new Symbol("bool") ||
           symbol == new Symbol("String");
  }

  String _formatKeyToSnake(String name) {
    var rname = name.replaceAllMapped(new RegExp("(.)([A-Z][a-z]+)"), (match) {
      return "${match.group(1)}_${match.group(2)}";
    });
    rname = rname.replaceAllMapped(new RegExp("([a-z0-9])([A-Z])"), (match) {
      return "${match.group(1)}_${match.group(2)}";
    }).toLowerCase();
    return rname;
  }

  String _formatKeyFromSnake(String name) {
    return name.replaceAllMapped(new RegExp("_([a-z0-9])"), (match) {
      return match.group(1).toUpperCase();
    });
  }
}

class Test {
  String test;
  String v;
  int top;
  double topf;
  bool isTrue;
  List<int> testList;
  Map<String, String> testMap;
  TestOther testObj;
  List<TestOther> testListOthers;

  Test();
  Test.init(this.test, this.v, this.top, this.topf, this.isTrue, this.testList, this.testMap, this.testObj, this.testListOthers);

  String toString() {
    return "$test, $v, $top, $topf, $isTrue, $testList, $testMap, $testObj, $testListOthers";
  }
}

class TestOther {
  String test;
  int top;

  TestOther();
  TestOther.init(this.test, this.top);
}