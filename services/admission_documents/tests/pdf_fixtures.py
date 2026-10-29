"""Synthetic PDF bytes for format validation; never real identity evidence."""
from io import BytesIO
from pypdf import PdfWriter
from pypdf.generic import DecodedStreamObject, ArrayObject, DictionaryObject, NameObject, NumberObject, TextStringObject


def certificate_pdf(pages=1, *, encrypted=False, password='fixture-password', javascript=False,
                    attachment=False, xfa=False, large_stream=False, broken_content=False,
                    external_stream=False, external_action=False):
    writer=PdfWriter()
    for _ in range(pages): writer.add_blank_page(width=595,height=842)
    writer.add_metadata({'/Title':'Synthetic certificate validation fixture'})
    if javascript:
        writer.root_object[NameObject('/OpenAction')]=DictionaryObject({NameObject('/S'):NameObject('/JavaScript'),NameObject('/JS'):TextStringObject("app.alert('synthetic active content');")})
    if external_action:
        action=DictionaryObject({NameObject('/S'):writer._add_object(NameObject('/URI')),NameObject('/URI'):TextStringObject('https://example.invalid')})
        annotation=DictionaryObject({NameObject('/Type'):NameObject('/Annot'),NameObject('/Subtype'):NameObject('/Link'),NameObject('/Rect'):ArrayObject([NumberObject(0),NumberObject(0),NumberObject(20),NumberObject(20)]),NameObject('/A'):writer._add_object(action)})
        writer.pages[0][NameObject('/Annots')]=ArrayObject([writer._add_object(annotation)])
    if attachment: writer.add_attachment('embedded.txt',b'Synthetic embedded file')
    if xfa:
        writer.root_object[NameObject('/AcroForm')]=DictionaryObject({NameObject('/XFA'):TextStringObject('<template/>')})
    if large_stream or external_stream:
        stream=DecodedStreamObject();stream.set_data(bytes(33*1024*1024) if large_stream else b'Synthetic metadata')
        stream=stream.flate_encode()
        if external_stream: stream[NameObject('/F')]=TextStringObject('/untrusted/external/file')
        writer.root_object[NameObject('/Metadata')]=writer._add_object(stream)
    if broken_content:
        stream=DecodedStreamObject();stream.set_data(b'BT (unterminated string')
        writer.pages[0][NameObject('/Contents')]=writer._add_object(stream)
    if encrypted: writer.encrypt(password,algorithm='AES-256')
    out=BytesIO();writer.write(out);return out.getvalue()
