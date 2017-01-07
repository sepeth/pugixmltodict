# distutils: language = c++

from __future__ import unicode_literals
import sys
from libc.string cimport const_char
from libc.stddef cimport ptrdiff_t
from libcpp.string cimport string


PY3 = sys.version_info[0] == 3


cdef extern from "<sstream>" namespace "std" nogil:
    cdef cppclass stringstream:
        string str() const


cdef extern from "pugixml/src/pugixml.hpp" namespace "pugi" nogil:
    cdef cppclass xml_text:
        bint empty() const
        const_char* get() const

    cdef cppclass xml_attribute:
        const_char* name() const
        const_char* value() const
        bint empty() const

        # Get next/previous attribute in the attribute list of the parent node
        xml_attribute next_attribute() const
        xml_attribute previous_attribute() const

        # Set attribute name/value (returns false if attribute is empty or there
        # is not enough memory)
        bint set_name(const_char* rhs)
        bint set_value(const_char* rhs)

    cdef enum xml_node_type:
        node_null,         # Empty (null) node handle
        node_document,     # A document tree's absolute root
        node_element,      # Element tag, i.e. '<node/>'
        node_pcdata,       # Plain character data, i.e. 'text'
        node_cdata,        # Character data, i.e. '<![CDATA[text]]>'
        node_comment,      # Comment tag, i.e. '<!-- text -->'
        node_pi,           # Processing instruction, i.e. '<?name?>'
        node_declaration,  # Document declaration, i.e. '<?xml version="1.0"?>'
        node_doctype       # Document type declaration, i.e. '<!DOCTYPE doc>'

    cdef enum xml_encoding:
        encoding_auto,      # Auto-detect
        encoding_utf8,      # UTF8 encoding
        encoding_utf16_le,  # Little-endian UTF16
        encoding_utf16_be,  # Big-endian UTF16
        encoding_utf16,     # UTF16 with native endianness
        encoding_utf32_le,  # Little-endian UTF32
        encoding_utf32_be,  # Big-endian UTF32
        encoding_utf32,     # UTF32 with native endianness
        encoding_wchar,     # The same encoding wchar_t has (either UTF16 or UTF32)
        encoding_latin1

    cdef cppclass xml_node:
        # Check if node is empty.
        bint empty() const

        # Get node type
        xml_node_type type() const

        # Get node name, or "" if node is empty or it has no name
        const_char* name() const

        # Get node value, or "" if node is empty or it has no value
        # Note: For <node>text</node> node.value() does not return "text"!
        # Use child_value() or text() methods to access text inside nodes.
        const_char* value() const

        xml_attribute first_attribute() const
        xml_attribute last_attribute() const

        # Get children list
        xml_node first_child() const
        xml_node last_child() const

        # Get next/previous sibling in the children list of the parent node
        xml_node next_sibling() const
        xml_node previous_sibling() const

        # Get parent node
        xml_node parent() const

        # Get root of DOM tree this node belongs to
        xml_node root() const

        # Get text object for the current node
        xml_text text() const

        # Get child, attribute or next/previous sibling with the specified name
        xml_node child(const_char* name) const
        xml_attribute attribute(const_char* name) const
        xml_node next_sibling(const_char* name) const
        xml_node previous_sibling(const_char* name) const

        # Get child value of current node; that is, value of the first child
        # node of type PCDATA/CDATA
        const_char* child_value() const

        # Get child value of child with specified name.
        # Equivalent to child(name).child_value().
        const_char* child_value(const_char* name) const
        bint operator!() const

        # Set node name/value (returns false if node is empty,
        # there is not enough memory, or node can not have name/value)
        bint set_name(const_char* rhs)
        bint set_value(const_char* rhs)

        # Add attribute with specified name. Returns added attribute,
        # or empty attribute on errors.
        xml_attribute append_attribute(const_char* name)

        # Add child node with specified type. Returns added node,
        # or empty node on errors.
        xml_node append_child(const_char* name)
        xml_node append_child(xml_node_type type)

    cdef cppclass xml_parse_result:
        ptrdiff_t offset
        bint operator bool() const
        const_char* description() const

    cdef cppclass xml_writer:
        pass

    cdef cppclass xml_document(xml_node):
        xml_parse_result load_buffer(const char* contents, size_t size)
        void save(stringstream& stream, const_char* indent, unsigned int flags,
                  xml_encoding encoding) const



cdef unicodify(val):
    if isinstance(val, bytes):
        return val.decode('utf-8')
    if isinstance(val, list):
        return [unicodify(v) for v in val]
    if isinstance(val, dict):
        ret = {}
        for k, v in val.items():
            if isinstance(k, bytes):
                k = k.decode('utf-8')
            ret[k] = unicodify(v)
        return ret
    return val


cdef deunicodify(val):
    if isinstance(val, unicode):
        return val.encode('utf-8')
    if isinstance(val, list):
        return [unicodify(v) for v in val]
    if isinstance(val, dict):
        ret = {}
        for k, v in val.items():
            if isinstance(k, unicode):
                k = k.encode('utf-8')
            ret[k] = deunicodify(v)
        return ret
    return val


cdef walk(xml_node node):
    cdef xml_attribute attr = node.first_attribute()
    cdef xml_node child = node.first_child()
    cdef xml_node_type child_type
    cdef bint has_children = 0
    cdef xml_text text = node.text()
    cdef const_char* tag
    cdef bytes text_val = b""

    while not child.empty():
        child_type = child.type()
        if child_type != node_cdata and child_type != node_pcdata:
            has_children = 1
            break
        child = child.next_sibling()

    if attr.empty() and not has_children:
        if text.empty():
            return None
        return text.get().strip()

    cdef dict ret = {}

    while not attr.empty():
        ret[b'@' + attr.name()] = attr.value()
        attr = attr.next_attribute()

    child = node.first_child()
    while not child.empty():
        child_type = child.type()
        if child_type == node_element:
            tag = child.name()
            if tag in ret:
                if not isinstance(ret[tag], list):
                    ret[tag] = [ret[tag]]
                ret[tag].append(walk(child))
            else:
                ret[tag] = walk(child)
        elif child_type == node_cdata or child_type == node_pcdata:
            text_val += child.value()
        child = child.next_sibling()

    if text_val:
        ret[b'#text'] = text_val.strip()

    return ret or None


def parse(xml_input):
    cdef xml_document doc
    cdef xml_parse_result result
    cdef xml_node root
    cdef const_char* input_str
    cdef size_t input_len

    if isinstance(xml_input, unicode):
        xml_input = xml_input.encode('utf-8')

    input_str = xml_input
    input_len = len(xml_input)

    with nogil:
        result = doc.load_buffer(input_str, input_len)
        root = doc.first_child()
    if result:
        ret = {root.name(): walk(root)}
        if PY3:
            return unicodify(ret)
        return ret
    else:
        raise ValueError(
            '%s, at offset %d' % (result.description(), result.offset))


cdef unwalk_list(xml_node parent, const_char* name, list val):
    for sub in val:
        node = parent.append_child(name)
        unwalk(node, sub)


cdef unwalk(xml_node parent, val):
    if isinstance(val, unicode):
        parent.append_child(node_pcdata).set_value(val.encode('utf-8'))
    elif isinstance(val, bytes):
        parent.append_child(node_pcdata).set_value(val)
    elif val is None:
        parent.append_child(node_pcdata).set_value(b'')
    elif isinstance(val, dict):
        for k, v in val.items():
            if isinstance(k, unicode):
                k = k.encode('utf-8')
            if isinstance(v, unicode):
                v = v.encode('utf-8')
            if k[0] == b'@' or k[0] == 64: # is @ char
                parent.append_attribute(k[1:]).set_value(v)
            elif k == b'#text':
                unwalk(parent, v)
            elif isinstance(v, list):
                unwalk_list(parent, k, v)
            else:
                unwalk(parent.append_child(<bytes>k), v)
    else:
        parent.append_child(node_pcdata).set_value(str(val))


def unparse(xml_dict):
    cdef xml_document doc
    cdef stringstream ss
    cdef bytes ret
    cdef xml_node decl = doc.append_child(node_declaration)
    decl.append_attribute("version").set_value("1.0")
    if not PY3:
        decl.append_attribute("encoding").set_value("utf-8")
    else:
        xml_dict = deunicodify(xml_dict)
    unwalk(doc, xml_dict)
    doc.save(ss, "", 0, encoding_utf8)  # no indent
    ret = ss.str()
    if PY3:
        return ret.decode('utf-8')
    return ret
