"""Bounded PDF parsing subprocess. Receives private bytes only through stdin.

This is a structural/content-policy check, not certificate authenticity, digital
signature verification or a claim of complete malware detection. Never rewrite
source bytes: existing signatures and permanent source hashes are preserved.
"""
import sys


def validate(data):
    import logging
    import math
    import re
    import warnings
    from io import BytesIO
    from pypdf import PdfReader
    from pypdf.generic import ArrayObject, DictionaryObject, IndirectObject, StreamObject

    if not 1 <= len(data) <= 1_048_576 or not re.match(rb'%PDF-(?:1\.[0-7]|2\.0)[\r\n]', data) or not data.rstrip().endswith(b'%%EOF'):
        raise ValueError('Invalid PDF envelope')
    class RejectRepairs(logging.Handler):
        def emit(self, record):
            if record.levelno >= logging.WARNING:
                raise ValueError('PDF parser repair required')
    logger = logging.getLogger('pypdf')
    logger.handlers = [RejectRepairs()]
    logger.propagate = False
    logger.setLevel(logging.WARNING)
    warnings.simplefilter('error')
    def resolve(value):
        for _ in range(16):
            if not isinstance(value, IndirectObject):
                return value
            value = value.get_object()
        raise ValueError('Indirect selector complexity')

    reader = PdfReader(BytesIO(data), strict=True)
    if reader.is_encrypted or '/Encrypt' in reader.trailer:
        raise ValueError('Encrypted certificate')
    if not 1 <= len(reader.pages) <= 50:
        raise ValueError('Page limit')
    for page in reader.pages:
        unit = float(resolve(page.get('/UserUnit', 1)))
        dimensions = (float(page.mediabox.width) * unit, float(page.mediabox.height) * unit)
        if not math.isfinite(unit) or unit <= 0 or any(not math.isfinite(x) or not 0 < x <= 14400 for x in dimensions):
            raise ValueError('Page dimensions')
        contents = page.get_contents()
        if contents is not None:
            # Force parsing of page content syntax, not just its page-tree entry.
            if len(contents.operations) > 100_000:
                raise ValueError('Page content complexity')

    blocked_keys = {'/OpenAction', '/AA', '/JS', '/JavaScript', '/EmbeddedFiles', '/EF', '/AF', '/XFA',
                    '/RichMediaContent', '/RichMediaSettings', '/Collection'}
    actions = {'/JavaScript', '/Launch', '/URI', '/GoTo', '/GoToR', '/GoToE', '/SubmitForm', '/ImportData',
               '/ResetForm', '/Hide', '/Named', '/Sound', '/Movie', '/Rendition', '/Trans', '/GoTo3DView',
               '/RichMediaExecute', '/SetOCGState', '/Thread'}
    blocked_types = {'/Filespec', '/EmbeddedFile', '/Action'}
    blocked_subtypes = {'/FileAttachment', '/RichMedia', '/Movie', '/Sound', '/3D', '/Screen'}
    stack = [reader.trailer]
    references, containers = set(), set()
    decoded = 0
    nodes = 0
    while stack:
        nodes += 1
        if nodes > 10_000:
            raise ValueError('Object complexity')
        obj = stack.pop()
        if isinstance(obj, IndirectObject):
            key = (obj.idnum, obj.generation)
            if key in references:
                continue
            references.add(key)
            obj = obj.get_object()
        if isinstance(obj, (DictionaryObject, ArrayObject)):
            if id(obj) in containers:
                continue
            containers.add(id(obj))
        if isinstance(obj, DictionaryObject):
            if blocked_keys.intersection(obj.keys()):
                raise ValueError('Active content or attachment')
            selectors = [resolve(obj.get(k)) for k in ('/Type', '/S', '/Subtype')]
            if any(isinstance(v, str) and v in denied for v, denied in zip(selectors, (blocked_types, actions, blocked_subtypes))):
                raise ValueError('Active content or attachment')
            if isinstance(obj, StreamObject):
                if '/F' in obj:
                    raise ValueError('External stream')
                decoded += len(obj.get_data())
                if decoded > 32 * 1024 * 1024:
                    raise ValueError('Decoded stream limit')
                if selectors[2] == '/Image':
                    width, height = int(resolve(obj.get('/Width', 0))), int(resolve(obj.get('/Height', 0)))
                    if min(width, height) <= 0 or width * height > 20_000_000:
                        raise ValueError('Embedded image size')
            stack.extend(obj.values())
        elif isinstance(obj, ArrayObject):
            stack.extend(obj)
    reader.close()


def main():
    # Set limits in the child after exec; preexec_fn is unsafe with threaded
    # upload workers. Unsupported platforms fail closed, with no parser fallback.
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024, 256 * 1024 * 1024))
    resource.setrlimit(resource.RLIMIT_CPU, (3, 3))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (0, 0))
    resource.setrlimit(resource.RLIMIT_NOFILE, (32, 32))
    data = sys.stdin.buffer.read(1_048_577)
    validate(data)


if __name__ == '__main__':
    try:
        main()
    except BaseException:
        sys.exit(1)
