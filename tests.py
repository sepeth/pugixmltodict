import unittest
from pugixmltodict import parse, unparse


class XmlToDictTestCase(unittest.TestCase):
    def test_minimal(self):
        self.assertEqual(parse('<a/>'), {'a': None})

    def test_simple(self):
        self.assertEqual(parse('<a>data</a>'), {'a': 'data'})

    def test_list(self):
        self.assertEqual(parse('<a><b>1</b><b>2</b><b>3</b></a>'),
                         {'a': {'b': ['1', '2', '3']}})

    def test_attrib(self):
        self.assertEqual(parse('<a href="xyz"/>'),
                         {'a': {'@href': 'xyz'}})

    def test_attrib_and_text(self):
        self.assertEqual(parse('<a href="xyz">123</a>'),
                         {'a': {'@href': 'xyz', '#text': '123'}})

    def test_semi_structured(self):
        self.assertEqual(parse('<a>abc<b/>def</a>'),
                         {'a': {'b': None, '#text': 'abcdef'}})

    def test_nested_semi_structured(self):
        self.assertEqual(parse('<a>abc<b>123<c/>456</b>def</a>'),
                         {'a': {'#text': 'abcdef', 'b': {
                             '#text': '123456', 'c': None}}})

    def test_skip_whitespace(self):
        xml = """
        <root>
          <emptya>           </emptya>
          <emptyb attr="attrvalue">
          </emptyb>
          <value>hello</value>
        </root>
        """
        self.assertEqual(
            parse(xml),
            {'root': {'emptya': None,
                      'emptyb': {'@attr': 'attrvalue'},
                      'value': 'hello'}})

    def test_namespace_ignore(self):
        xml = """
        <root xmlns="http://defaultns.com/"
              xmlns:a="http://a.com/"
              xmlns:b="http://b.com/">
          <x>1</x>
          <a:y>2</a:y>
          <b:z>3</b:z>
        </root>
        """
        d = {
            'root': {
                '@xmlns': 'http://defaultns.com/',
                '@xmlns:a': 'http://a.com/',
                '@xmlns:b': 'http://b.com/',
                'x': '1',
                'a:y': '2',
                'b:z': '3',
            },
        }
        self.assertEqual(parse(xml), d)

    def test_with_broken_attribute(self):
        with self.assertRaises(ValueError):
            parse('<root attr>foo</root>')

    def test_with_mismatched_tag(self):
        with self.assertRaises(ValueError):
            parse('<root attr="val">text</wrong>')


class DictToXmlTestCase(unittest.TestCase):
    def test_root(self):
        obj = {'a': None}
        self.assertEqual(obj, parse(unparse(obj)))
        self.assertEqual(unparse(obj), unparse(parse(unparse(obj))))

    def test_simple_text(self):
        obj = {'a': 'b'}
        self.assertEqual(obj, parse(unparse(obj)))
        self.assertEqual(unparse(obj), unparse(parse(unparse(obj))))

    def test_attrib(self):
        obj = {'a': {'@href': 'x'}}
        self.assertEqual(obj, parse(unparse(obj)))
        self.assertEqual(unparse(obj), unparse(parse(unparse(obj))))

    def test_attrib_and_text(self):
        obj = {'a': {'@href': 'x', '#text': 'y'}}
        self.assertEqual(obj, parse(unparse(obj)))
        self.assertEqual(unparse(obj), unparse(parse(unparse(obj))))

    def test_list(self):
        obj = {'a': {'b': ['1', '2', '3']}}
        self.assertEqual(obj, parse(unparse(obj)))
        self.assertEqual(unparse(obj), unparse(parse(unparse(obj))))
