# Railway Volume Permission Fix

## Issue: `mkdir: cannot create directory '/data/.openclaw': Permission denied`

This happens when Railway mounts a volume but the container user doesn't have write permissions.

## Root Cause

Nixpacks runs containers as a non-root user (uid 1000) for security. Railway volumes need to be configured with proper ownership.

## Solution: Configure Volume Ownership in Railway

### Option A: Set Volume Mount Permissions (Recommended)

In Railway dashboard:

1. Go to your service → **Settings** → **Volumes**
2. **Delete the existing volume** (if data loss is acceptable)
3. Click **"+ New Volume"**
4. Configure:
   - **Mount Path**: `/data`
   - **Size**: 1GB
5. After adding, Railway should auto-configure ownership

### Option B: Use Railway's Volume Mount Syntax

Add a Railway environment variable to specify volume ownership:

```bash
# In Railway Variables tab
RAILWAY_VOLUME_MOUNT_PATH=/data
```

Railway automatically handles ownership when using their volume system correctly.

## Fallback Strategy

The updated `railway-start.sh` includes a fallback:

- ✅ **First try**: Create directories in `/data` (persistent volume)
- ⚠️ **Fallback**: If permission denied, use `$HOME/.openclaw` (ephemeral but writable)

This ensures the service **starts successfully** even if the volume isn't configured, but **data won't persist** with the fallback.

## Verify Volume is Working

After deployment, check logs for:

### Success (Volume working):
```
Creating directories...
✓ Created /data/.openclaw
```

### Fallback (Volume not working):
```
⚠ Permission denied creating /data/.openclaw
⚠ Falling back to home directory
✓ Using fallback: /home/user/.openclaw
```

If you see the fallback, **data will NOT persist** across deploys.

## Debugging Steps

### 1. Check Volume Mount Path

In Railway dashboard:
- Service → Settings → Volumes
- Verify Mount Path is **exactly** `/data`
- Not `/data/` or `/data/openclaw` or anything else

### 2. Check Volume Ownership

Connect via Railway CLI:
```bash
railway connect
railway run bash
ls -ld /data
# Should show: drwxr-xr-x ... user user ... /data
```

If ownership is wrong (e.g., `root root`), the volume needs to be recreated or permissions fixed.

### 3. Manual Permission Fix (Temporary)

If you have existing data and can't recreate the volume:

```bash
railway connect
railway run bash
# This requires root access - may not work in Railway
sudo chown -R $(id -u):$(id -g) /data
```

## Expected Behavior After Fix

✅ Service starts successfully
✅ Logs show: `✓ Created /data/.openclaw`
✅ Configuration persists across deploys
✅ Telegram stays enabled
✅ Conversation history persists

---

**Current Status**: Script updated with fallback. Deploy to test. If you see "Using fallback", the volume needs to be reconfigured.
