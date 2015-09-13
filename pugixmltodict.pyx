# distutils: language = c++
# distutils: sources = pugixml/src/pugixml.cpp

from libc.string cimport const_char


cdef extern from "pugixml/src/pugixml.hpp" namespace "pugi":
    cdef cppclass xml_text:
        bint empty() nogil const
        const_char* get() nogil const

    cdef cppclass xml_attribute:
        const_char* name() nogil const
        const_char* value() nogil const
        bint empty() nogil const

        # Get next/previous attribute in the attribute list of the parent node
        xml_attribute next_attribute() nogil const
        xml_attribute previous_attribute() nogil const

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

    cdef cppclass xml_node:
        # Check if node is empty.
        bint empty() nogil const

        # Get node type
        xml_node_type type() nogil const

        # Get node name, or "" if node is empty or it has no name
        const_char* name() nogil const

        # Get node value, or "" if node is empty or it has no value
        # Note: For <node>text</node> node.value() does not return "text"!
        # Use child_value() or text() methods to access text inside nodes.
        const_char* value() nogil const

        xml_attribute first_attribute() nogil const
        xml_attribute last_attribute() nogil const

        # Get children list
        xml_node first_child() nogil const
        xml_node last_child() nogil const

        # Get next/previous sibling in the children list of the parent node
        xml_node next_sibling() nogil const
        xml_node previous_sibling() nogil const

        # Get parent node
        xml_node parent() nogil const

        # Get root of DOM tree this node belongs to
        xml_node root() nogil const

        # Get text object for the current node
        xml_text text() nogil const

        # Get child, attribute or next/previous sibling with the specified name
        xml_node child(const_char* name) nogil const
        xml_attribute attribute(const_char* name) nogil const
        xml_node next_sibling(const_char* name) nogil const
        xml_node previous_sibling(const_char* name) nogil const

        # Get child value of current node; that is, value of the first child node of type PCDATA/CDATA
        const_char* child_value() nogil const

        # Get child value of child with specified name. Equivalent to child(name).child_value().
        const_char* child_value(const_char* name) nogil const
        bint operator!() nogil const

    cdef cppclass xml_parse_result:
        bint operator bool() nogil const

    cdef cppclass xml_document(xml_node):
        xml_parse_result load_buffer(const char* contents, size_t size) nogil


cdef walk(xml_node node):
    cdef xml_attribute attr = node.first_attribute()
    cdef xml_node child = node.first_child()
    cdef xml_node_type child_type
    cdef bint has_children = 0
    cdef xml_text text = node.text()
    cdef const_char* tag
    cdef str text_val = ""

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
        ret['@' + attr.name()] = attr.value()
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
        ret['#text'] = text_val.strip()

    return ret or None


def parse(xml_input):
    cdef xml_document doc
    cdef xml_parse_result result
    cdef xml_node root
    cdef size_t input_len = len(xml_input)
    cdef const_char* input_str = xml_input
    with nogil:
        doc.load_buffer(input_str, input_len)
        root = doc.first_child()
    return {root.name(): walk(root)}
