import React, { useState, useCallback, useEffect } from "react";
import { useDropzone } from "react-dropzone";

const DropZone = ({
  onFileUploaded,
  accept,
  maxFiles = 1,
  responseType,
  token,
}) => {
  const [previews, setPreviews] = useState([]);
  const [error, setError] = useState(null);
  const [progress, setProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);

  const onDrop = useCallback(
    async (acceptedFiles, rejectedFiles) => {
      setError(null);
      setProgress(0);
      setIsUploading(true);

      // Проверка токена
      if (!token) {
        setError("Токен аутентификации отсутствует");
        setIsUploading(false);
        return;
      }

      // Проверка ошибок загрузки
      if (rejectedFiles.length > 0) {
        setError(
          `Ошибка: Загрузите файлы формата ${accept.join(", ")} (максимум ${maxFiles})`,
        );
        setIsUploading(false);
        return;
      }

      if (acceptedFiles.length === 0) {
        setError("Выберите хотя бы один файл");
        setIsUploading(false);
        return;
      }

      // Создаём предварительный просмотр
      const newPreviews = acceptedFiles.map((file) => ({
        file,
        preview: [
          "image/webp",
          "image/jpeg",
          "image/png",
          "image/gif",
        ].includes(file.type)
          ? URL.createObjectURL(file)
          : null,
      }));
      setPreviews(newPreviews);

      // Формируем запрос
      const formData = new FormData();
      formData.append("file", acceptedFiles[0]);
      formData.append("response_type", responseType);

      try {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:4000/api/upload", true);

        // Устанавливаем заголовок Authorization
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);

        // Отслеживание прогресса
        xhr.upload.onprogress = (event) => {
          if (event.lengthComputable) {
            const percent = Math.round((event.loaded / event.total) * 100);
            setProgress(percent);
          }
        };

        // Обработка ответа
        xhr.onload = () => {
          setIsUploading(false);
          console.log("Server response:", xhr.status, xhr.responseText); // Для отладки
          if (xhr.status === 200) {
            if (!xhr.responseText) {
              setError("Сервер вернул пустой ответ");
              return;
            }
            try {
              const data = JSON.parse(xhr.responseText);
              if (data.error) {
                setError(data.error);
              } else if (data.file_id || data.url) {
                onFileUploaded(data.file_id || data.url);
              } else {
                setError("Ответ сервера не содержит file_id или url");
              }
            } catch (parseError) {
              console.error(
                "JSON parse error:",
                parseError,
                "Response:",
                xhr.responseText,
              );
              setError("Ошибка парсинга ответа сервера: некорректный JSON");
            }
          } else {
            let errorMessage = `Ошибка сервера: ${xhr.status}`;
            if (xhr.responseText) {
              try {
                const data = JSON.parse(xhr.responseText);
                errorMessage = data.error || errorMessage;
              } catch {
                errorMessage = xhr.responseText.slice(0, 100) || errorMessage;
              }
            }
            setError(errorMessage);
          }
        };

        xhr.onerror = () => {
          setIsUploading(false);
          setError("Ошибка сети при загрузке файла");
        };

        xhr.send(formData);
      } catch (err) {
        setIsUploading(false);
        setError(err.message || "Неизвестная ошибка");
      }
    },
    [onFileUploaded, accept, maxFiles, responseType, token],
  );

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: accept.reduce((acc, type) => ({ ...acc, [type]: [] }), {}),
    maxFiles,
    maxSize: 10 * 1024 * 1024, // 10MB
    disabled: isUploading,
  });

  // Очистка URL предварительного просмотра
  useEffect(() => {
    return () =>
      previews.forEach((p) => p.preview && URL.revokeObjectURL(p.preview));
  }, [previews]);

  return (
    <div className="mb-4">
      <div
        {...getRootProps()}
        className={`border-2 border-dashed border-gray-600 p-6 rounded-md text-center cursor-pointer transition-colors ${
          isDragActive
            ? "bg-gray-700 border-blue-500"
            : "bg-gray-800 hover:bg-gray-700"
        } ${isUploading ? "opacity-50 cursor-not-allowed" : ""}`}
      >
        <input {...getInputProps()} />
        {isDragActive ? (
          <p className="text-blue-400">Отпустите файл здесь...</p>
        ) : (
          <p className="text-gray-300">
            Перетащите файл сюда или кликните для выбора (макс. {maxFiles}, до
            10 МБ)
          </p>
        )}
      </div>
      {error && <p className="text-red-500 text-sm mt-2">{error}</p>}
      {isUploading && (
        <div className="mt-2 bg-gray-700 rounded-full h-2">
          <div
            className="bg-blue-500 h-2 rounded-full transition-all duration-300"
            style={{ width: `${progress}%` }}
          ></div>
        </div>
      )}
      {previews.length > 0 && (
        <div className="mt-4 grid grid-cols-1 gap-4">
          {previews.map((p, index) => (
            <div key={index} className="flex items-center space-x-4">
              {p.preview ? (
                <img
                  src={p.preview}
                  alt="Preview"
                  className="w-16 h-16 object-cover rounded-md"
                  onError={(e) => (e.target.src = "/placeholder.png")}
                />
              ) : (
                <div className="w-16 h-16 bg-gray-700 rounded-md flex items-center justify-center">
                  <span className="text-gray-400 text-sm">Файл</span>
                </div>
              )}
              <p className="text-gray-300 text-sm truncate max-w-xs">
                {p.file.name}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default DropZone;
