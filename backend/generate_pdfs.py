#!/usr/bin/env python3
"""
Generates minimal valid 1-page placeholder PDFs for seed books.
Run once at Docker image build time.
"""
import os

BOOKS_DIR = '/app/uploads/books'
os.makedirs(BOOKS_DIR, exist_ok=True)

BOOKS = [
    ('moby-dick.pdf',           'Moby Dick - Herman Melville'),
    ('great-gatsby.pdf',        'The Great Gatsby - F. Scott Fitzgerald'),
    ('dune.pdf',                'Dune - Frank Herbert'),
    ('pride-and-prejudice.pdf', 'Pride and Prejudice - Jane Austen'),
    ('1984.pdf',                '1984 - George Orwell'),
]


def create_placeholder_pdf(title: str) -> bytes:
    line1 = title.encode('latin-1', errors='replace')
    line2 = b'Upload the real PDF to replace this placeholder.'

    stream_body = (
        b'BT\n/F1 18 Tf\n72 780 Td\n(' + line1 + b') Tj\n'
        b'0 -28 Td\n/F1 11 Tf\n(' + line2 + b') Tj\nET\n'
    )

    # Object 1 – Catalog
    obj1 = b'1 0 obj\n<</Type /Catalog /Pages 2 0 R>>\nendobj\n'
    # Object 2 – Pages
    obj2 = b'2 0 obj\n<</Type /Pages /Kids [3 0 R] /Count 1>>\nendobj\n'
    # Object 3 – Page (A4: 595x842)
    obj3 = (
        b'3 0 obj\n'
        b'<</Type /Page /Parent 2 0 R /MediaBox [0 0 595 842]\n'
        b'  /Contents 4 0 R\n'
        b'  /Resources <</Font <</F1 <</Type /Font /Subtype /Type1 /BaseFont /Helvetica>>>>>>\n'
        b'>>\nendobj\n'
    )
    # Object 4 – Content stream
    obj4 = (
        b'4 0 obj\n'
        b'<</Length ' + str(len(stream_body)).encode() + b'>>\n'
        b'stream\n' + stream_body + b'endstream\nendobj\n'
    )

    # Build body and record offsets
    body = b'%PDF-1.4\n'
    offsets = []
    for obj in (obj1, obj2, obj3, obj4):
        offsets.append(len(body))
        body += obj

    # xref table
    xref_pos = len(body)
    xref = b'xref\n0 5\n0000000000 65535 f \n'
    for off in offsets:
        xref += ('%010d 00000 n \n' % off).encode()

    trailer = (
        b'trailer\n<</Size 5 /Root 1 0 R>>\n'
        b'startxref\n' + str(xref_pos).encode() + b'\n%%EOF\n'
    )

    return body + xref + trailer


for filename, title in BOOKS:
    path = os.path.join(BOOKS_DIR, filename)
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        data = create_placeholder_pdf(title)
        with open(path, 'wb') as f:
            f.write(data)
        print(f'  Created {filename} ({len(data)} bytes)')
    else:
        print(f'  Exists  {filename}')

print('Done.')
