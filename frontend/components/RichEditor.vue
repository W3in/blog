<script setup lang="ts">
import { useEditor, EditorContent } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import { TextStyle, Color, BackgroundColor, FontFamily } from '@tiptap/extension-text-style'
import TextAlign from '@tiptap/extension-text-align'
import FileHandler from '@tiptap/extension-file-handler'
import { Placeholder } from '@tiptap/extensions'
import { message } from 'ant-design-vue'

const props = defineProps<{ modelValue: string; placeholder?: string }>()
const emit = defineEmits<{ 'update:modelValue': [string] }>()
const { headers } = useAuth()

// Same list as Api::UploadsController (Rails checks again, this only gives a quicker message)
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
const MAX_SIZE = 5 * 1024 * 1024
// New images start at most this wide; drag the corners or use Nhỏ/Vừa/Tràn to change it
const DEFAULT_IMAGE_WIDTH = 640

const TEXT_COLORS = [
  { name: 'Xám', value: '#868e96' }, { name: 'Đỏ', value: '#e03131' }, { name: 'Cam', value: '#e8590c' },
  { name: 'Vàng đậm', value: '#f08c00' }, { name: 'Xanh lá', value: '#2f9e44' }, { name: 'Xanh ngọc', value: '#0c8599' },
  { name: 'Xanh dương', value: '#1971c2' }, { name: 'Tím', value: '#6741d9' }, { name: 'Hồng', value: '#c2255c' }
]
const HIGHLIGHTS = [
  { name: 'Vàng', value: '#fff3bf' }, { name: 'Xanh lá', value: '#d3f9d8' }, { name: 'Xanh dương', value: '#d0ebff' },
  { name: 'Hồng', value: '#ffe3e3' }, { name: 'Tím', value: '#f3d9fa' }, { name: 'Cam', value: '#ffe8cc' }
]
// The families come from the @fontsource packages loaded in nuxt.config.ts
const FONTS = [
  { name: 'Hiện đại', value: "'Be Vietnam Pro', sans-serif" },
  { name: 'Sang trọng', value: "'Playfair Display', serif" },
  { name: 'Dễ đọc (sách)', value: "'Lora', serif" },
  { name: 'Viết tay', value: "'Dancing Script', cursive" },
  { name: 'Máy đánh chữ', value: 'ui-monospace, monospace' }
]

const ALIGNS = ['left', 'center', 'right'] 
const AlignedImage = Image.extend({
  addAttributes(){
    return {
      ...this.parent?.(),
      align: {
        default: null,
        parseHTML: element => ALIGNS.includes(element.dataset.align ?? '') ? element.dataset.align : null,
        renderHTML: attrs => attrs.align ? { 'data-align': attrs.align } : {}
      }
    }
  }
})

// useEditor builds the editor in the browser only (after mount), so on the server `editor` is undefined
const editor = useEditor({
  content: props.modelValue,
  extensions: [
    StarterKit.configure({
      heading: { levels: [2, 3] }, // h1 is the article title
      link: { openOnClick: false, autolink: true, defaultProtocol: 'https' }
    }),
    // resize: drag a corner of a selected image; the size is saved as width/height on the <img>
    AlignedImage.configure({
      resize: { enabled: true, directions: ['top-left', 'top-right', 'bottom-left', 'bottom-right'], minWidth: 80, minHeight: 60, alwaysPreserveAspectRatio: true }
    }),
    TextStyle, Color, BackgroundColor, FontFamily, // <span style="color / background-color / font-family">
    TextAlign.configure({ types: ['heading', 'paragraph'], alignments: ['left', 'center', 'right'] }),
    // Paste (Ctrl+V a screenshot) or drop an image file into the text: upload it like the image button
    FileHandler.configure({
      allowedMimeTypes: IMAGE_TYPES,
      onPaste: (_editor, files, html) => {
        if (html) return // copied from a web page: the normal HTML paste already brings the picture
        files.forEach(file => insertImage(file))
      },
      onDrop: (_editor, files, pos) => files.forEach(file => insertImage(file, pos))
    }),
    Placeholder.configure({ placeholder: props.placeholder ?? 'Viết nội dung...' })
  ],
  // The editor holds the text; the parent form gets it as HTML on every change
  onUpdate: ({ editor }) => emit('update:modelValue', editor.getHTML())
})

// Every button: focus back into the text, run one command
const run = () => editor.value!.chain().focus()
const active = (name: string | Record<string, unknown>, attrs?: Record<string, unknown>) =>
  !!(typeof name === 'string' ? editor.value?.isActive(name, attrs) : editor.value?.isActive(name))
const textStyle = computed(() => editor.value?.getAttributes('textStyle') ?? {})

// --- Popovers (color, highlight, font, link): close after a choice ---
const open = reactive({ color: false, highlight: false, font: false, link: false })
function pick(which: keyof typeof open, command: () => void) {
  command()
  open[which] = false
}

// --- Link ---
const linkUrl = ref('')
watch(() => open.link, (isOpen) => {
  if (isOpen) linkUrl.value = editor.value?.getAttributes('link').href ?? ''
})
function applyLink() {
  const url = linkUrl.value.trim()
  if (!url) {
    run().extendMarkRange('link').unsetLink().run()
  } else if (editor.value!.state.selection.empty && !active('link')) {
    // Nothing selected: insert the URL itself as a link
    run().insertContent({ type: 'text', text: url, marks: [{ type: 'link', attrs: { href: url } }] }).run()
  } else {
    run().extendMarkRange('link').setLink({ href: url }).run()
  }
  open.link = false
}

// --- Images ---
const fileInput = ref<HTMLInputElement>()
const uploading = ref(0) // how many uploads are still running

// Width/height of a picture file, read in the browser before uploading
function naturalSize(file: File) {
  return new Promise<{ width: number; height: number } | null>((resolve) => {
    const img = new window.Image()
    const url = URL.createObjectURL(file)
    img.onload = () => { resolve({ width: img.naturalWidth, height: img.naturalHeight }); URL.revokeObjectURL(url) }
    img.onerror = () => { resolve(null); URL.revokeObjectURL(url) }
    img.src = url
  })
}

async function insertImage(file: File, pos?: number) {
  if (!IMAGE_TYPES.includes(file.type)) return message.error('Chỉ nhận ảnh PNG, JPG, GIF hoặc WebP')
  if (file.size > MAX_SIZE) return message.error('Ảnh tối đa 5MB')

  uploading.value++
  try {
    const body = new FormData()
    body.append('file', file)
    const [{ url }, size] = await Promise.all([
      $fetch<{ url: string }>('/api/uploads', { method: 'POST', body, headers: headers.value }),
      naturalSize(file)
    ])
    // Big photos start at DEFAULT_IMAGE_WIDTH instead of filling the whole column
    const width = size ? Math.min(size.width, DEFAULT_IMAGE_WIDTH) : undefined
    const height = size && width ? Math.round(width * size.height / size.width) : undefined
    const node = { type: 'image', attrs: { src: url, alt: file.name.replace(/\.[^.]+$/, ''), width, height } }
    if (pos === undefined) run().insertContent(node).run()
    else editor.value!.chain().insertContentAt(pos, node).focus().run()
  } catch (e: any) {
    message.error(e.data?.file?.[0] ? `Ảnh ${e.data.file[0]}` : 'Không tải ảnh lên được')
  } finally {
    uploading.value--
  }
}

function onPickImage(event: Event) {
  const input = event.target as HTMLInputElement
  Array.from(input.files ?? []).forEach(file => insertImage(file))
  input.value = '' // so picking the same file again still fires "change"
}

// Nhỏ / Vừa / Tràn for the selected image: keep its proportions, null = as wide as the column
function resizeImage(width: number | null) {
  const ed = editor.value!
  const img = (ed.view.nodeDOM(ed.state.selection.from) as HTMLElement | null)?.querySelector('img')
  const ratio = img?.naturalWidth ? img.naturalHeight / img.naturalWidth : null
  const attrs = width && ratio ? { width, height: Math.round(width * ratio) } : { width: null, height: null }
  run().updateAttributes('image', attrs).run()
  // The resizable view only redraws itself while you drag a corner, so show the new size the same way it does
  if (img) {
    img.style.width = attrs.width ? `${attrs.width}px` : ''
    img.style.height = attrs.height ? `${attrs.height}px` : ''
  }
}

function align(value: 'left' | 'center' | 'right') {
  if (active('image')) run().updateAttributes('image', { align: value === 'center' ? null : value }).run()
  else run().setTextAlign(value).run()
}
const isAligned = (value: string) =>
  active('image') ? (editor.value?.getAttributes('image').align ?? 'center') === value : active({ textAlign: value })

</script>

<template>
  <div class="editor">
    <!-- Sticky: stays under the site header while writing a long post.
         mousedown.prevent: clicking a button must not take the cursor out of the text -->
    <div class="toolbar" role="toolbar" aria-label="Định dạng" @mousedown.prevent>
      <button type="button" class="tool" :class="{ on: active('bold') }" :disabled="!editor" title="In đậm (Ctrl+B)" aria-label="In đậm" @click="run().toggleBold().run()"><BoldOutlined /></button>
      <button type="button" class="tool" :class="{ on: active('italic') }" :disabled="!editor" title="In nghiêng (Ctrl+I)" aria-label="In nghiêng" @click="run().toggleItalic().run()"><ItalicOutlined /></button>
      <button type="button" class="tool" :class="{ on: active('underline') }" :disabled="!editor" title="Gạch chân (Ctrl+U)" aria-label="Gạch chân" @click="run().toggleUnderline().run()"><UnderlineOutlined /></button>
      <button type="button" class="tool" :class="{ on: active('strike') }" :disabled="!editor" title="Gạch ngang" aria-label="Gạch ngang" @click="run().toggleStrike().run()"><StrikethroughOutlined /></button>
      <span class="sep" />

      <!-- Font: each choice is written in its own font -->
      <a-popover v-model:open="open.font" trigger="click" placement="bottom">
        <template #content>
          <div class="menu" @mousedown.prevent>
            <button type="button" class="menu-item" @click="pick('font', () => run().unsetFontFamily().run())">Mặc định</button>
            <button v-for="f in FONTS" :key="f.value" type="button" class="menu-item" :class="{ on: textStyle.fontFamily === f.value }" :style="{ fontFamily: f.value }" @click="pick('font', () => run().setFontFamily(f.value).run())">{{ f.name }}</button>
          </div>
        </template>
        <button type="button" class="tool" :class="{ on: !!textStyle.fontFamily }" :disabled="!editor" title="Font chữ" aria-label="Font chữ"><FontSizeOutlined /></button>
      </a-popover>

      <!-- Text color: the bar under the icon shows the current color -->
      <a-popover v-model:open="open.color" trigger="click" placement="bottom">
        <template #content>
          <div class="swatches" @mousedown.prevent>
            <button type="button" class="swatch none" aria-label="Màu mặc định" title="Mặc định" @click="pick('color', () => run().unsetColor().run())">✕</button>
            <button v-for="c in TEXT_COLORS" :key="c.value" type="button" class="swatch" :style="{ background: c.value }" :aria-label="`Chữ màu ${c.name}`" :title="c.name" @click="pick('color', () => run().setColor(c.value).run())" />
          </div>
        </template>
        <button type="button" class="tool" :disabled="!editor" title="Màu chữ" aria-label="Màu chữ">
          <span class="with-bar"><FontColorsOutlined /><span class="bar" :style="{ background: textStyle.color ?? 'transparent' }" /></span>
        </button>
      </a-popover>

      <!-- Highlight: light background behind the selected text -->
      <a-popover v-model:open="open.highlight" trigger="click" placement="bottom">
        <template #content>
          <div class="swatches" @mousedown.prevent>
            <button type="button" class="swatch none" aria-label="Bỏ tô nền" title="Bỏ tô nền" @click="pick('highlight', () => run().unsetBackgroundColor().run())">✕</button>
            <button v-for="c in HIGHLIGHTS" :key="c.value" type="button" class="swatch" :style="{ background: c.value }" :aria-label="`Tô nền ${c.name}`" :title="c.name" @click="pick('highlight', () => run().setBackgroundColor(c.value).run())" />
          </div>
        </template>
        <button type="button" class="tool" :disabled="!editor" title="Tô nền chữ" aria-label="Tô nền chữ">
          <span class="with-bar"><HighlightOutlined /><span class="bar" :style="{ background: textStyle.backgroundColor ?? 'transparent' }" /></span>
        </button>
      </a-popover>
      <span class="sep" />

      <button type="button" class="tool text" :class="{ on: active('heading', { level: 2 }) }" :disabled="!editor" title="Tiêu đề lớn" aria-label="Tiêu đề lớn" @click="run().toggleHeading({ level: 2 }).run()">H2</button>
      <button type="button" class="tool text" :class="{ on: active('heading', { level: 3 }) }" :disabled="!editor" title="Tiêu đề nhỏ" aria-label="Tiêu đề nhỏ" @click="run().toggleHeading({ level: 3 }).run()">H3</button>
      <button type="button" class="tool" :class="{ on: isAligned('left') }" :disabled="!editor" title="Căn trái" aria-label="Căn trái" @click="align('left')"><AlignLeftOutlined /></button>
      <button type="button" class="tool" :class="{ on: isAligned('center') }" :disabled="!editor" title="Căn giữa" aria-label="Căn giữa" @click="align('center')"><AlignCenterOutlined /></button>
      <button type="button" class="tool" :class="{ on: isAligned('right') }" :disabled="!editor" title="Căn phải" aria-label="Căn phải" @click="align('right')"><AlignRightOutlined /></button>
      <span class="sep" />

      <button type="button" class="tool" :class="{ on: active('bulletList') }" :disabled="!editor" title="Danh sách chấm" aria-label="Danh sách chấm" @click="run().toggleBulletList().run()"><UnorderedListOutlined /></button>
      <button type="button" class="tool" :class="{ on: active('orderedList') }" :disabled="!editor" title="Danh sách số" aria-label="Danh sách số" @click="run().toggleOrderedList().run()"><OrderedListOutlined /></button>
      <button type="button" class="tool text" :class="{ on: active('blockquote') }" :disabled="!editor" title="Trích dẫn" aria-label="Trích dẫn" @click="run().toggleBlockquote().run()">❝</button>
      <button type="button" class="tool" :class="{ on: active('codeBlock') }" :disabled="!editor" title="Khối code" aria-label="Khối code" @click="run().toggleCodeBlock().run()"><CodeOutlined /></button>
      <span class="sep" />

      <a-popover v-model:open="open.link" trigger="click" placement="bottom">
        <template #content>
          <div class="link-form">
            <a-input v-model:value="linkUrl" size="small" placeholder="https://..." @press-enter="applyLink" />
            <a-button size="small" type="primary" @click="applyLink">{{ linkUrl.trim() ? 'Gắn link' : 'Bỏ link' }}</a-button>
          </div>
        </template>
        <button type="button" class="tool" :class="{ on: active('link') }" :disabled="!editor" title="Gắn link" aria-label="Gắn link"><LinkOutlined /></button>
      </a-popover>
      <button type="button" class="tool" :disabled="!editor" title="Chèn ảnh (hoặc dán / kéo thả ảnh vào bài, tối đa 5MB)" aria-label="Chèn ảnh" @click="fileInput?.click()">
        <LoadingOutlined v-if="uploading" /><PictureOutlined v-else />
      </button>
      <input ref="fileInput" type="file" :accept="IMAGE_TYPES.join(',')" multiple hidden @change="onPickImage">

      <!-- Only while an image is selected: quick sizes (dragging a corner also works) -->
      <template v-if="active('image')">
        <span class="sep" />
        <button type="button" class="tool text" title="Ảnh nhỏ (240px)" @click="resizeImage(240)">Nhỏ</button>
        <button type="button" class="tool text" title="Ảnh vừa (420px)" @click="resizeImage(420)">Vừa</button>
        <button type="button" class="tool text" title="Ảnh rộng bằng cột chữ" @click="resizeImage(null)">Tràn</button>
      </template>
      <span class="sep" />

      <button type="button" class="tool" :disabled="!editor?.can().undo()" title="Hoàn tác (Ctrl+Z)" aria-label="Hoàn tác" @click="run().undo().run()"><UndoOutlined /></button>
      <button type="button" class="tool" :disabled="!editor?.can().redo()" title="Làm lại (Ctrl+Shift+Z)" aria-label="Làm lại" @click="run().redo().run()"><RedoOutlined /></button>
    </div>

    <EditorContent :editor="editor" class="rich-content editor-body" />
    <p class="hint muted">Mẹo: dán (Ctrl+V) hoặc kéo thả ảnh thẳng vào bài. Bấm vào ảnh rồi kéo các góc để đổi cỡ.</p>
  </div>
</template>

<style scoped>
/* One box like an Ant Design input: grey border, blue when you are typing inside */
.editor {
  border: 1px solid #d9d9d9;
  border-radius: 8px;
  background: #fff;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.editor:focus-within {
  border-color: #1677ff;
  box-shadow: 0 0 0 2px rgba(5, 145, 255, 0.1);
}

.toolbar {
  position: sticky;
  top: 60px; /* height of the sticky site header */
  z-index: 2;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px;
  padding: 6px 8px;
  border-bottom: 1px solid #f0f0f0;
  border-radius: 8px 8px 0 0;
  background: #fafafa;
}

/* Plain <button>: small square icon buttons, Ant's a-button is too big for a toolbar */
.tool {
  min-width: 32px;
  height: 32px;
  padding: 0 6px;
  border: 0;
  border-radius: 6px;
  background: transparent;
  color: rgba(0, 0, 0, 0.75);
  font: inherit;
  font-size: 15px;
  cursor: pointer;
}

.tool.text {
  font-weight: 600;
  font-size: 13px;
}

.tool:hover:not(:disabled) {
  background: #f0f0f0;
}

/* Formatting that is already on where the cursor is */
.tool.on {
  background: #e6f4ff;
  color: #1677ff;
}

.tool:disabled {
  color: rgba(0, 0, 0, 0.25);
  cursor: not-allowed;
}

/* Icon with a small color bar under it (current text color / highlight) */
.with-bar {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
}

.bar {
  width: 16px;
  height: 3px;
  border-radius: 2px;
}

.sep {
  width: 1px;
  height: 20px;
  margin: 0 4px;
  background: #e5e5e5;
}

.swatches {
  display: grid;
  grid-template-columns: repeat(5, 28px);
  gap: 6px;
}

.swatch {
  width: 28px;
  height: 28px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 50%;
  cursor: pointer;
}

.swatch:hover {
  transform: scale(1.1);
}

.swatch.none {
  background: #fff;
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}

.menu {
  display: flex;
  flex-direction: column;
  min-width: 180px;
}

.menu-item {
  padding: 6px 10px;
  border: 0;
  border-radius: 6px;
  background: transparent;
  font-size: 16px;
  text-align: left;
  cursor: pointer;
}

.menu-item:hover,
.menu-item.on {
  background: #f5f5f5;
}

.link-form {
  display: flex;
  gap: 8px;
  width: 280px;
}

.hint {
  margin: 0;
  padding: 6px 16px 8px;
  border-top: 1px solid #f5f5f5;
  font-size: 12px;
}

/* .ProseMirror is the editable area TipTap creates inside EditorContent, so it needs :deep */
.editor-body :deep(.ProseMirror) {
  min-height: 280px;
  padding: 12px 16px;
  outline: none;
}

/* Grey hint text while the editor is empty (the text comes from the Placeholder extension) */
.editor-body :deep(.ProseMirror p.is-editor-empty:first-child::before) {
  content: attr(data-placeholder);
  float: left;
  height: 0;
  color: rgba(0, 0, 0, 0.25);
  pointer-events: none;
}

/* --- Resizable images: TipTap wraps each <img> in containers with 4 corner handles (no styles of its own) --- */
.editor-body :deep([data-resize-container]) {
  justify-content: center;
  margin: 1em 0;
}

.editor-body :deep([data-resize-container]:has(img[data-align="left"])) { justify-content: flex-start; }
.editor-body :deep([data-resize-container]:has(img[data-align="right"])) { justify-content: flex-end; }

.editor-body :deep([data-resize-wrapper] img) {
  margin: 0;
}

/* The image you clicked on */
.editor-body :deep(.ProseMirror-selectednode img) {
  outline: 3px solid #1677ff;
}

.editor-body :deep([data-resize-handle]) {
  width: 12px;
  height: 12px;
  margin: -6px; /* centered on the image corner */
  border: 2px solid #1677ff;
  border-radius: 3px;
  background: #fff;
  opacity: 0;
  transition: opacity 0.15s;
}

/* Handles show on hover and while the image is selected */
.editor-body :deep([data-resize-wrapper]:hover [data-resize-handle]),
.editor-body :deep(.ProseMirror-selectednode [data-resize-handle]) {
  opacity: 1;
}

.editor-body :deep([data-resize-handle='top-left']),
.editor-body :deep([data-resize-handle='bottom-right']) {
  cursor: nwse-resize;
}

.editor-body :deep([data-resize-handle='top-right']),
.editor-body :deep([data-resize-handle='bottom-left']) {
  cursor: nesw-resize;
}
</style>
